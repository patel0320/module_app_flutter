// lib/services/module_status/soleux_json_service.dart
//
// Persistent JSON-protocol command service for Soleux devices, implemented
// against the transport/JSON split described in
// doc/Soleux-Mobile-TCP-Protocol.md §"Transport" and §"JSON protocol".
//
//   - one persistent, auto-reconnecting socket per device (reused via
//     [ModuleTcpConnection]);
//   - a buffered CR/LF line reader (never assume one read == one message);
//   - JSON responses matched by `id`, never by arrival order; a unique `id`
//     guards every outstanding request;
//   - non-`J:` lines (welcome status dump, unsolicited `OUT:`/`IN:` state,
//     `OVERRIDE:`, `GETENERGY:`, `OK`, `Error : Function Disabled`, ...) are
//     routed to [eventStream] as parsed [SoleuxLegacyEvent]s.
//
// Command framing lives here; rendering onto a [DeviceModule] is the job of the
// Soleux JSON fetcher (soleux_json_fetcher.dart).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/soleux/soleux_json_protocol.dart';
import 'module_tcp_service.dart';

/// One in-flight JSON request waiting for its `J:` response.
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

/// Persistent JSON-protocol command service for one Soleux device.
class SoleuxJsonService {
  final ModuleTcpConnection _connection;

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

  /// Unsolicited (no pending request) `J:` lines, e.g. pushed configuration
  /// updates, decoded as raw maps.
  Stream<Map<String, dynamic>> get jsonEventStream => _jsonEvents.stream;

  /// Connection up/down transitions, forwarded from [ModuleTcpConnection].
  Stream<bool> get connectionStateStream => _connection.connectionStateStream;

  bool get isConnected => _connection.isConnected;

  SoleuxJsonService({required ModuleTcpConnection connection})
      : _connection = connection {
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
    _connection.write(
        SoleuxJsonRequest(id: id, action: action, params: params).encode());
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

  /// Sends a raw legacy `AT+...` line (required for simple live control) and
  /// returns the accumulated response text up to (and including) the
  /// `OK`/`ERROR` terminator, or everything received before [timeout] elapses.
  ///
  /// Requests are CRLF-terminated per the protocol
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
