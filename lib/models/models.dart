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

/// Physical switch input behaviour - brief section 2.2.
enum InputMode { momentary, toggle, associated }

extension InputModeX on InputMode {
  String get label {
    switch (this) {
      case InputMode.momentary:
        return 'Momentary';
      case InputMode.toggle:
        return 'Toggle';
      case InputMode.associated:
        return 'Associated';
    }
  }

  String get description {
    switch (this) {
      case InputMode.momentary:
        return 'The action is executed only while the button is pressed.';
      case InputMode.toggle:
        return 'Each press toggles the state (ON/OFF) of an output or scenario.';
      case InputMode.associated:
        return 'The input is linked directly to a specific output or scenario.';
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

/// Encodes an [IconData] for JSON storage (glyph codepoint + optional font).
Map<String, Object?> iconToJson(IconData icon) => {
      'fontFamily': icon.fontFamily,
      'codePoint': icon.codePoint,
    };

/// Rebuilds an [IconData] from the JSON produced by [iconToJson].
IconData iconFromJson(Object? json) {
  if (json is! Map) return Icons.power;
  final codePoint = (json['codePoint'] as num?)?.toInt() ?? Icons.power.codePoint;
  final family = json['fontFamily'] as String?;
  return IconData(codePoint, fontFamily: family);
}

/// A physical switch wired to a module (brief section 2.2).
class PhysicalInput {
  PhysicalInput({
    required this.id,
    required this.label,
    this.mode = InputMode.toggle,
    this.boundTo = 'Not assigned',
  });

  final String id;
  final String label;
  InputMode mode;
  String boundTo;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'mode': mode.name,
        'boundTo': boundTo,
      };

  factory PhysicalInput.fromJson(Map<String, Object?> json) => PhysicalInput(
        id: json['id'] as String,
        label: json['label'] as String,
        mode: InputMode.values.byName(json['mode'] as String),
        boundTo: json['boundTo'] as String? ?? 'Not assigned',
      );
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

  /// TCP port the module listens on (default 5005). Backed by a nullable
  /// field so legacy persisted JSON (or any null) degrades to the default.
  int? _tcpPort;
  int get tcpPort => _tcpPort ?? 5005;
  set tcpPort(int value) => _tcpPort = value;

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

  String get summary =>
      isDimmerAction ? '$channelName -> $brightnessPct%' : '$channelName -> ${turnOn ? 'ON' : 'OFF'}';

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
    List<ScenarioAction>? actions,
  }) : actions = actions ?? <ScenarioAction>[];

  final String id;
  String name;
  bool enabled;
  AutomationTriggerType triggerType;
  String triggerSummary;
  final List<ScenarioAction> actions;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'triggerType': triggerType.name,
        'triggerSummary': triggerSummary,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory Automation.fromJson(Map<String, Object?> json) => Automation(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        triggerType: AutomationTriggerType.values.byName(json['triggerType'] as String),
        triggerSummary: json['triggerSummary'] as String? ?? '',
        actions: [
          for (final a in json['actions'] as List? ?? const [])
            ScenarioAction.fromJson((a as Map).cast<String, Object?>()),
        ],
      );
}

/// A single row in the 30-day event history (brief section 2.4).
class EventLogEntry {
  EventLogEntry({required this.time, required this.title, required this.subtitle});

  final DateTime time;
  final String title;
  final String subtitle;
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
