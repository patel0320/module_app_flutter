// lib/services/module_status/soleux_json_service.dart
//
// Persistent Control API / JSON command service for Soleux devices, implemented
// against the transport/JSON split described in
// doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport and message
// envelope".
//
//   - one persistent, auto-reconnecting socket per device (reused via
//     [ModuleTcpConnection]);
//   - a buffered CR/LF line reader (never assume one read == one message);
//   - JSON responses matched by `id`, never by arrival order; a unique `id`
//     guards every outstanding request;
//   - the Control API framing (a plain JSON object per line, no `J:` prefix,
//     with the outer `protocol` field) is the default. [SoleuxJsonFraming.legacyJ]
//     selects the legacy `J:` framing for pre-Control-API devices;
//   - non-JSON lines (welcome status dump, unsolicited `OUT:`/`IN:` state,
//     `OVERRIDE:`, `GETENERGY:`, `OK`, `Error : Function Disabled`, ...) are
//     routed to [eventStream] as parsed [SoleuxLegacyEvent]s.
//
// Command framing lives here; rendering onto a [DeviceModule] is the job of the
// Soleux JSON fetcher (soleux_json_fetcher.dart).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/soleux/soleux_json_protocol.dart';
import 'module_tcp_service.dart';

/// Framing used on the wire for JSON protocol requests.
enum SoleuxJsonFraming {
  /// The Control API transport: one plain JSON object per line (no `J:`
  /// prefix), carrying the outer `protocol` field. Used on the Control API
  /// port (legacy TCP port + 3).
  controlApi,

  /// Legacy pre-Control-API framing: `J:`-prefixed JSON lines on the legacy
  /// TCP port.
  legacyJ,
}

/// One in-flight JSON request waiting for its response.
class _JsonPending {
  final Completer<SoleuxJsonResponse> completer;
  final Timer timer;

  _JsonPending({required this.completer, required this.timer});
}

/// Kind of a parsed non-JSON (legacy) line.
enum SoleuxLegacyEventType {
  output,
  input,
  overrideOn,
  overrideOff,
  energy,
  ok,
  error,
  other
}

/// A parsed non-JSON (legacy) line emitted by the device.
class SoleuxLegacyEvent {
  final String raw;
  final SoleuxLegacyEventType type;

  /// Channel for `OUT:<ch>:<ON|OFF>` / `IN:<ch>:<ON|OFF>`.
  final int? channel;

  /// ON/OFF state for output/input events.
  final bool? state;

  /// Scalar key/value pairs parsed from `KEY:value` lines.
  final Map<String, String> kv;

  const SoleuxLegacyEvent({
    required this.raw,
    required this.type,
    this.channel,
    this.state,
    this.kv = const {},
  });

  /// Parses one legacy line.
  static SoleuxLegacyEvent parse(String line) {
    final trimmed = line.trim();
    final field = RegExp(r'^(OUT|IN):(\d+):(ON|OFF)$').firstMatch(trimmed);
    if (field != null) {
      final isOut = field.group(1) == 'OUT';
      return SoleuxLegacyEvent(
        raw: trimmed,
        type:
            isOut ? SoleuxLegacyEventType.output : SoleuxLegacyEventType.input,
        channel: int.parse(field.group(2)!),
        state: field.group(3) == 'ON',
      );
    }
    if (trimmed == 'OVERRIDE:ON') {
      return SoleuxLegacyEvent(
          raw: trimmed, type: SoleuxLegacyEventType.overrideOn);
    }
    if (trimmed == 'OVERRIDE:OFF') {
      return SoleuxLegacyEvent(
          raw: trimmed, type: SoleuxLegacyEventType.overrideOff);
    }
    if (trimmed.startsWith('GETENERGY:')) {
      return SoleuxLegacyEvent(
        raw: trimmed,
        type: SoleuxLegacyEventType.energy,
        kv: {'value': trimmed.substring('GETENERGY:'.length)},
      );
    }
    if (trimmed == 'OK') {
      return SoleuxLegacyEvent(raw: trimmed, type: SoleuxLegacyEventType.ok);
    }
    if (trimmed == 'ERROR' ||
        trimmed.startsWith('Error') ||
        trimmed.startsWith('ERROR:')) {
      return SoleuxLegacyEvent(raw: trimmed, type: SoleuxLegacyEventType.error);
    }
    // Generic `KEY:value` scalar (SYSTEMP, VER, ...).
    final scalar =
        RegExp(r'^([A-Za-z_][A-Za-z0-9_]*):(.*)$').firstMatch(trimmed);
    if (scalar != null) {
      return SoleuxLegacyEvent(
        raw: trimmed,
        type: SoleuxLegacyEventType.other,
        kv: {scalar.group(1)!: scalar.group(2)!.trim()},
      );
    }
    return SoleuxLegacyEvent(raw: trimmed, type: SoleuxLegacyEventType.other);
  }
}

/// Persistent JSON protocol command service for one Soleux device.
class SoleuxJsonService {
  final ModuleTcpConnection _connection;

  /// Wire framing selected at construction ([SoleuxJsonFraming.controlApi] is
  /// the default).
  final SoleuxJsonFraming framing;

  final StreamController<SoleuxLegacyEvent> _events =
      StreamController<SoleuxLegacyEvent>.broadcast(sync: true);
  final StreamController<Map<String, dynamic>> _jsonEvents =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final SoleuxLineSplitter _splitter = SoleuxLineSplitter();
  final Map<int, _JsonPending> _pending = {};

  StreamSubscription<String>? _dataSubscription;
  int _nextId = 1;

  /// Parsed legacy/event lines from the device.
  Stream<SoleuxLegacyEvent> get eventStream => _events.stream;

  /// Unsolicited (no pending request) JSON lines, e.g. pushed configuration
  /// updates, decoded as raw maps.
  Stream<Map<String, dynamic>> get jsonEventStream => _jsonEvents.stream;

  /// Connection up/down transitions, forwarded from [ModuleTcpConnection].
  Stream<bool> get connectionStateStream => _connection.connectionStateStream;

  /// The underlying transport (exposes `port`/`key` for callers that probe
  /// different endpoints).
  ModuleTcpConnection get connection => _connection;

  bool get isConnected => _connection.isConnected;

  SoleuxJsonService({
    required ModuleTcpConnection connection,
    this.framing = SoleuxJsonFraming.controlApi,
  }) : _connection = connection {
    _dataSubscription = _connection.dataStream.listen(_handleData);
  }

  /// Opens the persistent connection.
  Future<void> connect() => _connection.connect();

  /// Closes the live socket and stops auto-reconnect.
  Future<void> disconnect() => _connection.disconnect();

  /// Feeds a chunk of wire data as if it had just arrived on the socket.
  /// Exposed for tests so routing/splitting logic can be exercised without
  /// real sockets.
  @visibleForTesting
  void feed(String chunk) => _handleData(chunk);

  /// Feeds decoded chunks through the buffered line splitter and routes each
  /// complete line: `J:` responses match pending requests by `id`; everything
  /// else becomes a legacy event.
  void _handleData(String chunk) {
    for (final line in _splitter.add(chunk)) {
      final response = SoleuxJsonResponse.maybeParse(line);
      if (response == null) {
        _events.add(SoleuxLegacyEvent.parse(line));
        continue;
      }
      final pending = _pending.remove(response.id);
      if (pending != null) {
        pending.timer.cancel();
        if (!pending.completer.isCompleted) {
          pending.completer.complete(response);
        }
      } else {
        // Unsolicited / unmatched JSON line - surface it as an event.
        _jsonEvents.add(response.result ?? {});
      }
    }
  }

  /// Allocates the next unique request id.
  int get _nextRequestId => _nextId++;

  /// Sends a JSON request and waits for its matching response.
  Future<SoleuxJsonResponse> request(
    String action,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_connection.isConnected) {
      throw Exception('Soleux JSON service not connected');
    }
    final id = _nextRequestId;
    if (_pending.containsKey(id)) {
      throw StateError('Duplicate request id: $id');
    }
    final completer = Completer<SoleuxJsonResponse>();
    final timer = Timer(timeout, () {
      _pending.remove(id);
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('Soleux JSON request $action (id $id) timed out'));
      }
    });
    _pending[id] = _JsonPending(completer: completer, timer: timer);
    _connection.write(SoleuxJsonRequest(
      id: id,
      action: action,
      params: params,
      protocol: SoleuxProtocolVersion.defaultRequest,
      legacyJPrefix: framing == SoleuxJsonFraming.legacyJ,
    ).encode());
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Convenience wrappers over the documented common actions.
  // ---------------------------------------------------------------------------

  /// `hello` - identifies protocol, device, name and channel counts.
  Future<SoleuxJsonResponse> hello(
          {Duration timeout = const Duration(seconds: 5)}) =>
      request(SoleuxJsonActions.hello, const {}, timeout: timeout);

  /// `get_relay_configuration` - full I/O + settings + mapping dump.
  Future<SoleuxJsonResponse> getRelayConfiguration(
          {Duration timeout = const Duration(seconds: 5)}) =>
      request(SoleuxJsonActions.getRelayConfiguration, const {},
          timeout: timeout);

  /// `get_page_configuration` - reads a device-driven configuration page.
  Future<SoleuxJsonResponse> getPageConfiguration(String page) =>
      request(SoleuxJsonActions.getPageConfiguration, {'page': page});

  /// `set_page_configuration` - saves one page section.
  Future<SoleuxJsonResponse> setPageConfiguration(
    String page,
    String section,
    Map<String, dynamic> values,
  ) =>
      request(SoleuxJsonActions.setPageConfiguration,
          {'page': page, 'section': section, 'values': values});

  /// `mutate_page_row` - add/update/delete a schedule, watchdog or ACL row.
  Future<SoleuxJsonResponse> mutatePageRow(
    String page,
    String section,
    String operation,
    Map<String, dynamic> values, {
    int? id,
  }) =>
      request(SoleuxJsonActions.mutatePageRow, {
        'page': page,
        'section': section,
        'operation': operation,
        if (id != null) 'id': id,
        'values': values,
      });

  /// `execute_page_action` - a page operation such as reboot or time sync.
  Future<SoleuxJsonResponse> executePageAction(
    String pageAction,
    Map<String, dynamic> actionData,
  ) =>
      request(SoleuxJsonActions.executePageAction,
          {'page_action': pageAction, ...actionData});

  /// `set_output_configuration` - one output's name/delays/runtime and (for
  /// dimmers) PWM.
  Future<SoleuxJsonResponse> setOutputConfiguration(
    int channel,
    Map<String, dynamic> values,
  ) =>
      request(SoleuxJsonActions.setOutputConfiguration,
          {'channel': channel, ...values});

  /// `set_input_configuration` - one physical input's configuration.
  Future<SoleuxJsonResponse> setInputConfiguration(
    int channel,
    Map<String, dynamic> values,
  ) =>
      request(SoleuxJsonActions.setInputConfiguration,
          {'channel': channel, ...values});

  /// `set_mapping` - input->output mapping (code 0..5).
  Future<SoleuxJsonResponse> setMapping(int input, int output, int code) =>
      request(SoleuxJsonActions.setMapping,
          {'input': input, 'output': output, 'code': code});

  /// `set_dimmer_frequency` (AC/DC Dimmer).
  Future<SoleuxJsonResponse> setDimmerFrequency(Map<String, dynamic> values) =>
      request(SoleuxJsonActions.setDimmerFrequency, values);

  /// `get_energy_history` (PDU Energy Meter). The date range must not exceed
  /// 365 days.
  Future<SoleuxJsonResponse> getEnergyHistory(
    SoleuxEnergyParameter parameter,
    String startDate,
    String endDate,
  ) =>
      request(SoleuxJsonActions.getEnergyHistory, {
        'parameter': parameter.index,
        'start_date': startDate,
        'end_date': endDate,
      });

  // ---------------------------------------------------------------------------
  // Control API catalogue commands (doc/...Specification_v0.2.md). These replace
  // the legacy AT+ control operations: set_output_state / toggle_output /
  // restart_output replace ON/OFF/TOGGLE/RESTART and masked AT operations,
  // set_dimmer_level replaces the dimmer brightness command, and ping replaces
  // `AT\r`. Unimplemented catalogue actions return the common
  // `unsupported_command` error, which the caller can use to fall back to the
  // implemented subset.
  // ---------------------------------------------------------------------------

  /// `ping` - reachability + round-trip estimate (§1.2). Result carries
  /// `server_time` and `uptime_ms`.
  Future<SoleuxJsonResponse> ping({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(SoleuxControlApiActions.ping, const {}, timeout: timeout);

  /// `get_capabilities` - supported commands, events and limits (§1.4).
  Future<SoleuxJsonResponse> capabilities({
    bool includeSchemas = false,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(SoleuxControlApiActions.getCapabilities,
          {'include_schemas': includeSchemas},
          timeout: timeout);

  /// `set_output_state` - set one output on/off (spec §4.3). Replaces
  /// `AT+ON`/`AT+OFF`.
  Future<SoleuxJsonResponse> setOutputState(
    int channel,
    bool state, {
    int? transitionMs,
    String? source,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.setOutputState,
          {
            'channel': channel,
            'state': state,
            if (transitionMs != null) 'transition_ms': transitionMs,
            if (source != null) 'source': source,
          },
          timeout: timeout);

  /// `toggle_output` - invert one output state (spec §4.4). Replaces
  /// `AT+TOGGLE`.
  Future<SoleuxJsonResponse> toggleOutput(
    int channel, {
    int? transitionMs,
    String? source,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.toggleOutput,
          {
            'channel': channel,
            if (transitionMs != null) 'transition_ms': transitionMs,
            if (source != null) 'source': source,
          },
          timeout: timeout);

  /// `restart_output` - cycle one output off and back on (spec §4.5).
  /// Replaces `AT+RESTART`.
  Future<SoleuxJsonResponse> restartOutput(
    int channel, {
    int? offTimeMs,
    String? restoreMode,
    String? source,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.restartOutput,
          {
            'channel': channel,
            if (offTimeMs != null) 'off_time_ms': offTimeMs,
            if (restoreMode != null) 'restore_mode': restoreMode,
            if (source != null) 'source': source,
          },
          timeout: timeout);

  /// `get_outputs` - read all output states (spec §4.1).
  Future<SoleuxJsonResponse> getOutputs({
    bool includeConfiguration = true,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(SoleuxControlApiActions.getOutputs,
          {'include_configuration': includeConfiguration},
          timeout: timeout);

  /// `get_inputs` - read all physical and virtual inputs (spec §3.1).
  Future<SoleuxJsonResponse> getInputs({
    bool includeConfiguration = true,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(SoleuxControlApiActions.getInputs,
          {'include_configuration': includeConfiguration},
          timeout: timeout);

  /// `get_device_state` - complete synchronization snapshot (spec §2.3).
  Future<SoleuxJsonResponse> getDeviceState({
    List<String> include = const ['inputs', 'outputs', 'sensors'],
    bool includeConfiguration = false,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.getDeviceState,
          {
            'include': include,
            'include_configuration': includeConfiguration,
          },
          timeout: timeout);

  /// `set_dimmer_level` - set one dimmer brightness level (spec §6.3).
  /// Replaces the legacy dimmer brightness AT command.
  Future<SoleuxJsonResponse> setDimmerLevel(
    int channel,
    double level, {
    int? transitionMs,
    bool? turnOn,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.setDimmerLevel,
          {
            'channel': channel,
            'level': level,
            if (transitionMs != null) 'transition_ms': transitionMs,
            if (turnOn != null) 'turn_on': turnOn,
          },
          timeout: timeout);

  /// `set_multiple_outputs` - set several outputs deterministically
  /// (spec §4.6). `targets` holds `{channel, state, transition_ms?}` maps.
  Future<SoleuxJsonResponse> setMultipleOutputs(
    List<Map<String, dynamic>> targets, {
    String? execution,
    int? intervalMs,
    bool stopOnError = false,
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(
          SoleuxControlApiActions.setMultipleOutputs,
          {
            'outputs': targets,
            if (execution != null) 'execution': execution,
            if (intervalMs != null) 'interval_ms': intervalMs,
            'stop_on_error': stopOnError,
          },
          timeout: timeout);

  /// `get_mappings` - read the input-output mapping matrix (spec §5.1).
  Future<SoleuxJsonResponse> getMappings({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      request(SoleuxControlApiActions.getMappings, const {}, timeout: timeout);

  /// Sends a raw legacy `AT+...` line and returns the accumulated response text
  /// up to (and including) the `OK`/`ERROR` terminator, or everything received
  /// before [timeout] elapses.
  ///
  /// This helper is only meaningful on the legacy path (a pre-Control-API
  /// device, or the AT-only legacy port). Modern live control uses the Control
  /// API catalogue commands ([setOutputState], [toggleOutput], [setDimmerLevel], ...).
  ///
  /// Requests are CRLF-terminated per the legacy protocol
  /// (doc/Soleux-Mobile-TCP-Protocol.md §"Transport").
  Future<String> legacy(String command,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    final subscription = _events.stream.listen((event) {
      buffer.writeln(event.raw);
      if (event.type == SoleuxLegacyEventType.ok ||
          event.type == SoleuxLegacyEventType.error) {
        if (!completer.isCompleted) completer.complete(buffer.toString());
      }
    });
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    });
    final wire = command.contains('\n') ? command : '$command\r\n';
    _connection.write(wire);
    final raw = await completer.future;
    timer.cancel();
    await subscription.cancel();
    return raw.trimRight();
  }

  void dispose() {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer
            .completeError(StateError('Soleux JSON service disposed'));
      }
    }
    _pending.clear();
    _dataSubscription?.cancel();
    _events.close();
    _jsonEvents.close();
    _connection.dispose();
  }

  /// Debug-friendly state for logging.
  @override
  String toString() =>
      'SoleuxJsonService(${_connection.key}, connected: $isConnected, '
      'outstanding: ${_pending.length})';
}
