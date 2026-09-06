// lib/models/models.dart
//
// Plain Dart data classes used by the static UI prototype. There is no
// backend, database, or network layer behind these models - screens create
// and mutate local copies in-memory only (see lib/data/mock_data.dart).
import 'package:flutter/material.dart';

/// The five dedicated hardware module types described in the brief
/// (section 2.3 "Extended Control Types").
enum ModuleType { relay, blind, dimmerDc, dimmerAc, temperature }

extension ModuleTypeX on ModuleType {
  String get label {
    switch (this) {
      case ModuleType.relay:
        return 'Standard Relay';
      case ModuleType.blind:
        return 'Blind Motor Control';
      case ModuleType.dimmerDc:
        return 'Lighting Dimmer (DC)';
      case ModuleType.dimmerAc:
        return 'Lighting Dimmer (AC)';
      case ModuleType.temperature:
        return 'Temperature Module';
    }
  }

  IconData get icon {
    switch (this) {
      case ModuleType.relay:
        return Icons.electrical_services;
      case ModuleType.blind:
        return Icons.blinds;
      case ModuleType.dimmerDc:
        return Icons.tune;
      case ModuleType.dimmerAc:
        return Icons.tune;
      case ModuleType.temperature:
        return Icons.thermostat;
    }
  }
}

/// Online / offline connectivity indicator shown throughout the app as a
/// green (online) or red (offline) dot - see brief section 2.1.
enum ConnectionStatus { online, offline }

/// Input field behaviour - the Control API `set_input_configuration` `mode`
/// (momentary | maintained | pulse), see
/// doc/Soleux_Control_API_Command_Specification_v0.3.md §3.3.
enum InputMode { momentary, maintained, pulse }

extension InputModeX on InputMode {
  String get label {
    switch (this) {
      case InputMode.momentary:
        return 'Momentary';
      case InputMode.maintained:
        return 'Maintained';
      case InputMode.pulse:
        return 'Pulse';
    }
  }

  String get description {
    switch (this) {
      case InputMode.momentary:
        return 'The action is executed only while the button is pressed.';
      case InputMode.maintained:
        return 'The state stays ON until the button is pressed again.';
      case InputMode.pulse:
        return 'A press pulses the input for a fixed duration, then releases it.';
    }
  }
}

/// Scenario kinds - brief section 2.4.
enum ScenarioType { tapToRun, manualSlider }

/// Smart automation trigger kinds - brief section 2.4.
enum AutomationTriggerType { time, deviceState }

/// A room / zone used to group modules and scenarios (brief section 2.5).
class Room {
  Room({required this.id, required this.name});

  final String id;
  String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  factory Room.fromJson(Map<String, Object?> json) =>
      Room(id: json['id'] as String, name: json['name'] as String? ?? '');
}

/// A single output/channel on a module (relay output, dimmer channel or
/// blind direction pair).
class ChannelOutput {
  ChannelOutput({
    required this.id,
    required this.name,
    required this.icon,
    this.isOn = false,
    this.brightness = 0,
  });

  final String id;
  String name;
  IconData icon;

  /// Relay / blind ON state.
  bool isOn;

  /// Dimmer brightness percentage, 0-100 (0 = OFF, 100 = fully ON).
  int brightness;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'icon': iconToJson(icon),
        'isOn': isOn,
        'brightness': brightness,
      };

  factory ChannelOutput.fromJson(Map<String, Object?> json) => ChannelOutput(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: iconFromJson(json['icon']),
        isOn: json['isOn'] as bool? ?? false,
        brightness: json['brightness'] as int? ?? 0,
      );
}

/// Const icons that can be persisted to JSON and rebuilt at runtime.
///
/// [IconData] must only be constructed from const glyph arguments for the
/// release build's icon tree-shaker to work; a runtime `IconData(...)` call
/// fails AOT compilation. Persisted JSON therefore references entries of this
/// registry (by name) instead of raw glyph codepoints. Keep in sync with
/// `kChannelIconChoices` in lib/data/mock_data.dart plus module default icons.
const Map<String, IconData> kPersistableIcons = {
  'lightbulb': Icons.lightbulb,
  'lightbulb_outline': Icons.lightbulb_outline,
  'light': Icons.light,
  'nightlight_round': Icons.nightlight_round,
  'wb_incandescent': Icons.wb_incandescent,
  'wb_sunny_outlined': Icons.wb_sunny_outlined,
  'tv': Icons.tv,
  'kitchen': Icons.kitchen,
  'water_drop': Icons.water_drop,
  'water': Icons.water,
  'ac_unit': Icons.ac_unit,
  'blinds': Icons.blinds,
  'deck': Icons.deck,
  'anchor': Icons.anchor,
  'directions_boat': Icons.directions_boat,
  'power': Icons.power,
  'electrical_services': Icons.electrical_services,
  'outdoor_grill': Icons.outdoor_grill,
  'garage': Icons.garage,
  'emoji_objects': Icons.emoji_objects,
  'tune': Icons.tune,
  'thermostat': Icons.thermostat,
};

Map<int, IconData>? _iconByCodePoint;

Map<int, IconData> get _iconByCodePointMap => _iconByCodePoint ??= {
      for (final icon in kPersistableIcons.values) icon.codePoint: icon,
    };

/// Encodes an [IconData] for JSON storage (stable name + glyph codepoint).
Map<String, Object?> iconToJson(IconData icon) {
  String? name;
  for (final entry in kPersistableIcons.entries) {
    if (entry.value.codePoint == icon.codePoint &&
        entry.value.fontFamily == icon.fontFamily) {
      name = entry.key;
      break;
    }
  }
  return {
    'name': name,
    'fontFamily': icon.fontFamily,
    'codePoint': icon.codePoint
  };
}

/// Rebuilds an [IconData] from the JSON produced by [iconToJson].
///
/// Looks icons up from const [kPersistableIcons] so no runtime
/// `IconData(...)` constructor is emitted (required by the icon tree-shaker).
IconData iconFromJson(Object? json) {
  if (json is! Map) return Icons.power;
  final byName = kPersistableIcons[json['name'] as String?];
  if (byName != null) return byName;
  final codePoint = (json['codePoint'] as num?)?.toInt();
  if (codePoint != null) return _iconByCodePointMap[codePoint] ?? Icons.power;
  return Icons.power;
}

/// An input field shown on a module screen: pressing-and-holding its action
/// button drives the associated virtual input (`set_virtual_input_state`), and
/// its configuration (name / behaviour / enabled) is pushed with
/// `set_input_configuration`.
class PhysicalInput {
  PhysicalInput({
    required this.id,
    required this.name,
    this.mode = InputMode.momentary,
    this.enabled = true,
  });

  final String id;
  String name;
  InputMode mode;

  /// When false the input is hidden from its module screen.
  bool enabled;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'mode': mode.name,
        'enabled': enabled,
      };

  factory PhysicalInput.fromJson(Map<String, Object?> json) => PhysicalInput(
        id: json['id'] as String,
        name: (json['name'] ?? json['label']) as String? ?? 'Switch',
        mode: _inputModeFromJson(json['mode']),
        enabled: json['enabled'] as bool? ?? true,
      );

  /// Maps a persisted `mode` value to [InputMode], tolerating the legacy
  /// `toggle` / `associated` values so old saved data still loads.
  static InputMode _inputModeFromJson(Object? raw) => switch (raw) {
        'momentary' => InputMode.momentary,
        'maintained' => InputMode.maintained,
        'pulse' => InputMode.pulse,
        'toggle' || 'associated' => InputMode.maintained,
        _ => InputMode.momentary,
      };
}

/// A hardware module added to the system (brief section 2.1).
class DeviceModule {
  DeviceModule({
    required this.id,
    required this.name,
    required this.type,
    required this.ipAddress,
    required this.status,
    required this.roomName,
    required this.internalTempC,
    int tcpPort = 5005,
    this.tempMinC = 0,
    this.tempMaxC = 60,
    this.firmware,
    this.serial,
    this.mac,
    this.apiPort,
    this.apiHttpPort,
    this.apiVersion,
    this.heartbeatPort,
    this.caps = const [],
    this.lastSeenAt,
    List<ChannelOutput>? channels,
    List<PhysicalInput>? inputs,
  })  : _tcpPort = tcpPort,
        channels = channels ?? <ChannelOutput>[],
        inputs = inputs ?? <PhysicalInput>[];

  final String id;
  String name;
  final ModuleType type;
  String ipAddress;

  /// Firmware/build reported by the module (e.g. `AT+VER` → `VER:`).
  String? firmware;

  /// Device serial number (identifies an individual physical device).
  String? serial;

  /// Ethernet MAC address (authoritative when reported by DCP).
  String? mac;

  /// Control API v3 TCP port when advertised by discovery (normally 5008).
  int? apiPort;

  /// Optional override of the Control API HTTP/HTTPS endpoint port
  /// (`POST /api/v1/command`). Defaults to 80 over HTTP and 443 over HTTPS per
  /// the Control API spec §"Transport mapping"; set it for development,
  /// testing or non-standard deployments.
  int? apiHttpPort;

  /// Highest advertised/negotiated Control API version (current 3).
  int? apiVersion;

  /// Advertised UDP heartbeat port (normally 5007). Null means the monitor
  /// derives it from [tcpPort] (`tcpPort + 2`).
  int? heartbeatPort;

  /// Advertised compact capability identifiers (`control_api_v3`, etc.).
  final List<String> caps;

  /// Last time the module answered a heartbeat pong (spec §4.2 `last_seen_at`).
  DateTime? lastSeenAt;

  /// UDP port heartbeat pings are directed at: advertised when present,
  /// otherwise the derived legacy `tcpPort + 2` (spec §3 endpoint selection).
  int get effectiveHeartbeatPort => heartbeatPort ?? tcpPort + 2;

  /// TCP port the module listens on (default 5005). Backed by a nullable
  /// field so legacy persisted JSON (or any null) degrades to the default.
  int? _tcpPort;
  int get tcpPort => _tcpPort ?? 5005;
  set tcpPort(int value) => _tcpPort = value;

  /// Control API TCP port used by the JSON Control API transport
  /// (doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport
  /// mapping"): the advertised [apiPort] when present, otherwise the legacy
  /// TCP port + 3 (`5005 -> 5008`). Per the discovery/heartbeat spec, when
  /// `API_PORT` is absent a client may probe `PORT + 3` but must complete the
  /// Control API `hello` exchange before treating the device as Control API.
  int get controlApiPort => apiPort ?? tcpPort + 3;

  /// Whether the module advertised the Control API transport (via discovery
  /// `API_PORT`/`API_VER`/`CAPS` or a heartbeat identity). Used to pick the
  /// Control API port and framing before a hello has been completed.
  bool get isControlApiAdvertised =>
      apiPort != null || apiVersion != null || caps.contains('control_api_v3');

  ConnectionStatus status;
  String roomName;

  /// Internal module temperature, monitored for every module type
  /// (brief section I, point 3).
  double internalTempC;
  double tempMinC;
  double tempMaxC;

  final List<ChannelOutput> channels;
  final List<PhysicalInput> inputs;

  bool get isOverTemperature =>
      internalTempC > tempMaxC || internalTempC < tempMinC;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'ipAddress': ipAddress,
        'tcpPort': tcpPort,
        'status': status.name,
        'roomName': roomName,
        'internalTempC': internalTempC,
        'tempMinC': tempMinC,
        'tempMaxC': tempMaxC,
        'firmware': firmware,
        'serial': serial,
        'mac': mac,
        'apiPort': apiPort,
        'apiHttpPort': apiHttpPort,
        'apiVersion': apiVersion,
        'heartbeatPort': heartbeatPort,
        'caps': caps,
        'lastSeenAt': lastSeenAt?.toIso8601String(),
        'channels': channels.map((c) => c.toJson()).toList(),
        'inputs': inputs.map((i) => i.toJson()).toList(),
      };

  factory DeviceModule.fromJson(Map<String, Object?> json) => DeviceModule(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ModuleType.values.byName(json['type'] as String),
        ipAddress: json['ipAddress'] as String,
        tcpPort: (json['tcpPort'] as num?)?.toInt() ?? 5005,
        status: ConnectionStatus.values.byName(json['status'] as String),
        roomName: json['roomName'] as String? ?? 'Unassigned',
        internalTempC: (json['internalTempC'] as num?)?.toDouble() ?? 0,
        tempMinC: (json['tempMinC'] as num?)?.toDouble() ?? 0,
        tempMaxC: (json['tempMaxC'] as num?)?.toDouble() ?? 60,
        firmware: json['firmware'] as String?,
        serial: json['serial'] as String?,
        mac: json['mac'] as String?,
        apiPort: (json['apiPort'] as num?)?.toInt(),
        apiHttpPort: (json['apiHttpPort'] as num?)?.toInt(),
        apiVersion: (json['apiVersion'] as num?)?.toInt(),
        heartbeatPort: (json['heartbeatPort'] as num?)?.toInt(),
        caps: [
          for (final c in json['caps'] as List? ?? const []) c as String,
        ],
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.tryParse(json['lastSeenAt'] as String),
        channels: [
          for (final c in json['channels'] as List? ?? const [])
            ChannelOutput.fromJson((c as Map).cast<String, Object?>()),
        ],
        inputs: [
          for (final i in json['inputs'] as List? ?? const [])
            PhysicalInput.fromJson((i as Map).cast<String, Object?>()),
        ],
      );
}

/// A single command executed by a scenario or automation.
class ScenarioAction {
  ScenarioAction({
    required this.moduleName,
    required this.channelName,
    required this.icon,
    required this.isDimmerAction,
    this.turnOn = true,
    this.brightnessPct = 100,
  });

  final String moduleName;
  final String channelName;
  final IconData icon;
  final bool isDimmerAction;
  final bool turnOn;
  final int brightnessPct;

  String get summary => isDimmerAction
      ? '$channelName -> $brightnessPct%'
      : '$channelName -> ${turnOn ? 'ON' : 'OFF'}';

  Map<String, Object?> toJson() => {
        'moduleName': moduleName,
        'channelName': channelName,
        'icon': iconToJson(icon),
        'isDimmerAction': isDimmerAction,
        'turnOn': turnOn,
        'brightnessPct': brightnessPct,
      };

  factory ScenarioAction.fromJson(Map<String, Object?> json) => ScenarioAction(
        moduleName: json['moduleName'] as String,
        channelName: json['channelName'] as String,
        icon: iconFromJson(json['icon']),
        isDimmerAction: json['isDimmerAction'] as bool? ?? false,
        turnOn: json['turnOn'] as bool? ?? true,
        brightnessPct: json['brightnessPct'] as int? ?? 100,
      );
}

/// A tap-to-run scenario or manual dimming slider (brief section 2.4).
class Scenario {
  Scenario({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    this.roomName = 'No room',
    this.showInHome = false,
    List<ScenarioAction>? actions,
    this.sliderTargetName = '',
    this.sliderValue = 0,
  }) : actions = actions ?? <ScenarioAction>[];

  final String id;
  String name;
  IconData icon;
  ScenarioType type;
  String roomName;
  bool showInHome;
  final List<ScenarioAction> actions;

  // Only used when [type] == ScenarioType.manualSlider.
  String sliderTargetName;
  int sliderValue;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'icon': iconToJson(icon),
        'type': type.name,
        'roomName': roomName,
        'showInHome': showInHome,
        'actions': actions.map((a) => a.toJson()).toList(),
        'sliderTargetName': sliderTargetName,
        'sliderValue': sliderValue,
      };

  factory Scenario.fromJson(Map<String, Object?> json) => Scenario(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: iconFromJson(json['icon']),
        type: ScenarioType.values.byName(json['type'] as String),
        roomName: json['roomName'] as String? ?? 'No room',
        showInHome: json['showInHome'] as bool? ?? false,
        actions: [
          for (final a in json['actions'] as List? ?? const [])
            ScenarioAction.fromJson((a as Map).cast<String, Object?>()),
        ],
        sliderTargetName: json['sliderTargetName'] as String? ?? '',
        sliderValue: json['sliderValue'] as int? ?? 0,
      );
}

/// An IF...THEN... smart automation (brief section 2.4).
class Automation {
  Automation({
    required this.id,
    required this.name,
    required this.triggerType,
    required this.triggerSummary,
    this.enabled = true,
    this.scheduleHour,
    this.scheduleMinute,
    this.watchChannelName,
    this.watchState = true,
    List<ScenarioAction>? actions,
  }) : actions = actions ?? <ScenarioAction>[];

  final String id;
  String name;
  bool enabled;
  AutomationTriggerType triggerType;
  String triggerSummary;
  final List<ScenarioAction> actions;

  /// Hour of the daily time trigger (0-23). Only meaningful when
  /// [triggerType] == AutomationTriggerType.time; null falls back to 20:00.
  int? scheduleHour;

  /// Minute of the daily time trigger (0-59). Only meaningful when
  /// [triggerType] == AutomationTriggerType.time.
  int? scheduleMinute;

  /// Output name watched by a device-state trigger. Only meaningful when
  /// [triggerType] == AutomationTriggerType.deviceState.
  String? watchChannelName;

  /// The state change that fires the rule: true = fires when the watched
  /// output turns ON, false = fires when it turns OFF.
  bool watchState;

  /// Falls back to a sensible default (20:00) for time-triggered rules that
  /// predate structured scheduling data.
  int get effectiveScheduleHour => scheduleHour ?? 20;

  int get effectiveScheduleMinute => scheduleMinute ?? 0;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'triggerType': triggerType.name,
        'triggerSummary': triggerSummary,
        'scheduleHour': scheduleHour,
        'scheduleMinute': scheduleMinute,
        'watchChannelName': watchChannelName,
        'watchState': watchState,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory Automation.fromJson(Map<String, Object?> json) => Automation(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        triggerType:
            AutomationTriggerType.values.byName(json['triggerType'] as String),
        triggerSummary: json['triggerSummary'] as String? ?? '',
        scheduleHour: (json['scheduleHour'] as num?)?.toInt(),
        scheduleMinute: (json['scheduleMinute'] as num?)?.toInt(),
        watchChannelName: json['watchChannelName'] as String?,
        watchState: json['watchState'] as bool? ?? true,
        actions: [
          for (final a in json['actions'] as List? ?? const [])
            ScenarioAction.fromJson((a as Map).cast<String, Object?>()),
        ],
      );
}

/// A single row in the 30-day event history (brief section 2.4).
class EventLogEntry {
  EventLogEntry(
      {required this.time, required this.title, required this.subtitle});

  final DateTime time;
  final String title;
  final String subtitle;

  Map<String, Object?> toJson() => {
        'time': time.toIso8601String(),
        'title': title,
        'subtitle': subtitle,
      };

  factory EventLogEntry.fromJson(Map<String, Object?> json) => EventLogEntry(
        time: DateTime.parse(json['time'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
      );
}

/// A single row in the System Status error/event log (brief section I, point 2).
class StatusLogEntry {
  StatusLogEntry({
    required this.time,
    required this.moduleName,
    required this.message,
    required this.isAlert,
  });

  final DateTime time;
  final String moduleName;
  final String message;

  /// True for offline / over-temperature alerts, false for recovery events.
  final bool isAlert;
}
