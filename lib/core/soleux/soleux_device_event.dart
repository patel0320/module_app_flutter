// lib/core/soleux/soleux_device_event.dart
//
// Codec for the Soleux Control API device events described in
// doc/Soleux_Control_API_Command_Specification_v0.6.md §"Device events".
//
// Events are unsolicited messages on subscribed TCP/WebSocket sessions or
// SSE streams. They use the `protocol`, `event`, `subscription_id` and `data`
// fields and do not contain `ok` or `result`:
//
//   {"protocol":3,"event":"output_state_changed","subscription_id":"sub-7",
//    "data":{"channel":0,"previous_state":false,"state":true,"pending":false,
//            "source":"windows-app","revision":312,
//            "timestamp":"2026-08-31T10:20:30+00:00"}}
//
// This file is deliberately networking-free: a pure codec that any transport
// (persistent socket, tests, mock) can use. On the newline-delimited TCP
// transport the device pushes one such object per line; the parser here both
// recognises the envelope (`event` plus no `ok`/`result`) and exposes the
// expected `data` fields of every documented event.
//
// Clients must treat events as incremental updates (spec §"Synchronization"):
// if revisions are skipped, a reconnecting client should call
// `get_device_state` to rebuild a complete snapshot.
library;

import 'dart:convert';

/// The documented Soleux Control API event catalogue
/// (doc/...Specification_v0.6.md §"Device events").
enum SoleuxDeviceEventType {
  outputStateChanged('output_state_changed'),
  outputLevelChanged('output_level_changed'),
  inputStateChanged('input_state_changed'),
  mappingChanged('mapping_changed'),
  temperatureChanged('temperature_changed'),
  energyChanged('energy_changed'),
  scheduleExecuted('schedule_executed'),
  automationExecuted('automation_executed'),
  sequenceStateChanged('sequence_state_changed'),
  operationProgress('operation_progress'),
  deviceFault('device_fault'),
  configurationChanged('configuration_changed'),
  deviceRebooting('device_rebooting'),

  /// Any `event` value not (yet) in the catalogue. Kept for strict switches
  /// and forward compatibility: unknown events are still surfaced raw.
  unknown('unknown');

  /// The exact `event` string sent on the wire.
  final String wire;

  const SoleuxDeviceEventType(this.wire);

  /// Maps a wire `event` value to its catalogued type (or [unknown]).
  static SoleuxDeviceEventType fromWire(String value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return SoleuxDeviceEventType.unknown;
  }
}

/// A parsed unsolicited device event (spec §"Device events").
///
/// [data] keeps the full payload for callers that need every field; the typed
/// getters below surface the documented fields of the current catalogue
/// (`channel`, `state`, `previous_state`, `pending`, `source`, `revision`,
/// `requested_level`/`actual_level`, ...).
class SoleuxDeviceEvent {
  /// Outer protocol version (`protocol`), when present.
  final int? protocol;

  /// Catalogued event kind ([unknown] for forward-compatible events).
  final SoleuxDeviceEventType type;

  /// The raw `event` string as sent by the device.
  final String rawEvent;

  /// `subscription_id` the event belongs to, when present.
  final String? subscriptionId;

  /// The decoded `data` payload (always a (possibly empty) map).
  final Map<String, dynamic> data;

  /// `data.timestamp` as `DateTime` (ISO 8601 with offset), when parseable.
  final DateTime? timestamp;

  /// `data.revision` - the device's incremental state revision, when present.
  final int? revision;

  const SoleuxDeviceEvent({
    this.protocol,
    required this.type,
    required this.rawEvent,
    this.subscriptionId,
    this.data = const {},
    this.timestamp,
    this.revision,
  });

  // ---------------------------------------------------------------------------
  // Shared / output & input fields (output_state_changed, input_state_changed,
  // output_level_changed, mapping_changed).
  // ---------------------------------------------------------------------------

  /// `data.channel` (output or input, zero-based).
  int? get channel => _intData('channel');

  /// `data.state` (output/input logical state).
  bool? get state => _boolData('state');

  /// `data.previous_state`.
  bool? get previousState => _boolData('previous_state');

  /// `data.pending` - true until hardware feedback matches the request.
  bool? get pending => _boolData('pending');

  /// `data.source` - the audit/source description that caused the change.
  String? get source => _stringData('source');

  /// `data.kind` - input kind (`physical`/`virtual`) for input events.
  String? get kind => _stringData('kind');

  /// `data.requested_level` (output_level_changed, 0-100).
  double? get requestedLevel => _numData('requested_level');

  /// `data.actual_level` (output_level_changed, 0-100).
  double? get actualLevel => _numData('actual_level');

  /// `data.transitioning` (output_level_changed) - dimmer is still settling.
  bool? get transitioning => _boolData('transitioning');

  // ---------------------------------------------------------------------------
  // Mapping (mapping_changed).
  // ---------------------------------------------------------------------------

  /// `data.input` - zero-based input side of a changed mapping.
  int? get mappingInput => _intData('input');

  /// `data.output` - zero-based output side of a changed mapping.
  int? get mappingOutput => _intData('output');

  /// `data.behavior` - numeric device mapping behavior code.
  int? get behavior => _intData('behavior');

  /// `data.legacy_code` - legacy numeric mapping behavior code.
  int? get legacyCode => _intData('legacy_code');

  // ---------------------------------------------------------------------------
  // Environment (temperature_changed, energy_changed).
  // ---------------------------------------------------------------------------

  /// `data.sensor_id` (temperature_changed).
  int? get sensorId => _intData('sensor_id');

  /// `data.value_c` (temperature_changed, °C).
  double? get valueC => _numData('value_c');

  /// `data.status` - reading status string (`ok`, `error`, ...).
  String? get readingStatus => _stringData('status');

  // ---------------------------------------------------------------------------
  // Schedule / automation / sequence / operation (execution events).
  // ---------------------------------------------------------------------------

  /// `data.schedule_id` (schedule_executed).
  int? get scheduleId => _intData('schedule_id');

  /// `data.automation_id` (automation_executed).
  int? get automationId => _intData('automation_id');

  /// `data.sequence_id` / `data.operation_id`.
  int? get sequenceId => _intData('sequence_id');
  int? get operationId => _intData('operation_id');

  /// `data.trigger` (automation_executed) or the current `state` label.
  String? get trigger => _stringData('trigger');

  /// `data.success` - whether the schedule/automation run succeeded.
  bool? get success => _boolData('success');

  /// `data.results` - per-action outcomes of a schedule/automation run.
  List<dynamic>? get results {
    final raw = data['results'];
    return raw is List ? raw : null;
  }

  /// `data.step` / `data.loop` (sequence_state_changed).
  int? get step => _intData('step');
  int? get loop => _intData('loop');

  // ---------------------------------------------------------------------------
  // Fault / progress / config / reboot.
  // ---------------------------------------------------------------------------

  /// `data.fault_id` (device_fault).
  int? get faultId => _intData('fault_id');

  /// `data.severity` (device_fault).
  String? get severity => _stringData('severity');

  /// `data.code` (device_fault) / `data.operation_id` fallback.
  String? get code => _stringData('code');

  /// `data.message`.
  String? get message => _stringData('message');

  /// `data.active` (device_fault).
  bool? get active => _boolData('active');

  /// `data.kind` for operation_progress / `data.stage` (operation_progress).
  String? get stage => _stringData('stage');

  /// `data.progress_percent` (operation_progress, 0-100).
  double? get progressPercent => _numData('progress_percent');

  /// `data.section` (configuration_changed).
  String? get section => _stringData('section');

  /// `data.restart_required` (configuration_changed).
  bool? get restartRequired => _boolData('restart_required');

  /// `data.reason` (device_rebooting).
  String? get reason => _stringData('reason');

  /// `data.reboot_in_ms` (device_rebooting).
  int? get rebootInMs => _intData('reboot_in_ms');

  // ---------------------------------------------------------------------------

  int? _intData(String key) {
    final raw = data[key];
    return raw is num ? raw.toInt() : null;
  }

  double? _numData(String key) {
    final raw = data[key];
    return raw is num ? raw.toDouble() : null;
  }

  bool? _boolData(String key) {
    final raw = data[key];
    return raw is bool ? raw : null;
  }

  String? _stringData(String key) {
    final raw = data[key];
    return raw is String ? raw : null;
  }

  /// Parses a raw event line into a [SoleuxDeviceEvent].
  ///
  /// Returns null when the line is not a JSON object carrying a string `event`
  /// field (i.e. a command response or a legacy line). Tolerates malformed
  /// JSON by returning null so one bad frame never kills the reader.
  static SoleuxDeviceEvent? maybeParse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final rawEvent = decoded['event'];
    if (rawEvent is! String) return null;
    return SoleuxDeviceEvent.parseEnvelope(decoded);
  }

  /// Builds an event from an already-decoded [envelope] map (used by
  /// [maybeParse] and by transports that decode JSON first).
  factory SoleuxDeviceEvent.parseEnvelope(Map<String, dynamic> envelope) {
    final rawEvent = envelope['event'];
    final data = envelope['data'];
    final dataMap = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    return SoleuxDeviceEvent(
      protocol: envelope['protocol'] is num
          ? (envelope['protocol'] as num).toInt()
          : null,
      type: rawEvent is String
          ? SoleuxDeviceEventType.fromWire(rawEvent)
          : SoleuxDeviceEventType.unknown,
      rawEvent: rawEvent is String ? rawEvent : '',
      subscriptionId: envelope['subscription_id'] as String?,
      data: dataMap,
      timestamp: _parseTimestamp(dataMap['timestamp']),
      revision: dataMap['revision'] is num
          ? (dataMap['revision'] as num).toInt()
          : null,
    );
  }

  static DateTime? _parseTimestamp(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
