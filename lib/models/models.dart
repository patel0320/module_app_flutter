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
    this.tempMinC = 0,
    this.tempMaxC = 60,
    List<ChannelOutput>? channels,
    List<PhysicalInput>? inputs,
  })  : channels = channels ?? <ChannelOutput>[],
        inputs = inputs ?? <PhysicalInput>[];

  final String id;
  String name;
  final ModuleType type;
  final String ipAddress;
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
