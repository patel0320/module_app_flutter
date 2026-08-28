// lib/data/mock_data.dart
//
// Hardcoded placeholder data for the static UI prototype. Every function
// below returns a brand-new set of objects so that each screen can mutate
// its own local copy (toggle a switch, move a slider, reorder a list...)
// without a shared backend or database - per the "static screens" brief.
import 'package:flutter/material.dart';

import '../models/models.dart';

DateTime _ago(Duration d) => DateTime.now().subtract(d);

/// Rooms / zones - brief section 2.5 (example names taken from the brief).
List<Room> mockRooms() => [
      Room(id: 'r1', name: 'Living Room'),
      Room(id: 'r2', name: 'Bedroom'),
      Room(id: 'r3', name: 'Deck'),
      Room(id: 'r4', name: 'Cabin'),
      Room(id: 'r5', name: 'Engine Room'),
    ];

/// The 5 dedicated module types, each with placeholder channels/inputs.
/// One relay has exactly 8 outputs and each dimmer has exactly 4 outputs,
/// matching the counts called out explicitly in the brief.
List<DeviceModule> mockModules() => [
      DeviceModule(
        id: 'm1',
        name: 'Main Cabin Relay',
        type: ModuleType.relay,
        ipAddress: '192.168.1.101',
        status: ConnectionStatus.online,
        roomName: 'Cabin',
        internalTempC: 34,
        tempMinC: 0,
        tempMaxC: 70,
        channels: [
          ChannelOutput(
              id: 'm1c1',
              name: 'Cabin Light',
              icon: Icons.lightbulb,
              isOn: true),
          ChannelOutput(
              id: 'm1c2', name: 'Navigation Lights', icon: Icons.explore),
          ChannelOutput(
              id: 'm1c3', name: 'Reading Lamp', icon: Icons.menu_book),
          ChannelOutput(
              id: 'm1c4', name: 'Kitchen Light', icon: Icons.light, isOn: true),
          ChannelOutput(
              id: 'm1c5', name: 'Deck Floodlight', icon: Icons.wb_incandescent),
          ChannelOutput(id: 'm1c6', name: 'Bilge Pump', icon: Icons.water_drop),
          ChannelOutput(
              id: 'm1c7', name: 'Fridge', icon: Icons.kitchen, isOn: true),
          ChannelOutput(id: 'm1c8', name: 'Water Pump', icon: Icons.water),
        ],
        inputs: [
          PhysicalInput(
              id: 'm1i1',
              label: 'Switch 1',
              mode: InputMode.toggle,
              boundTo: 'Cabin Light'),
          PhysicalInput(
              id: 'm1i2',
              label: 'Switch 2',
              mode: InputMode.associated,
              boundTo: 'Departure (scenario)'),
          PhysicalInput(
              id: 'm1i3',
              label: 'Switch 3',
              mode: InputMode.momentary,
              boundTo: 'Deck Floodlight'),
        ],
      ),
      DeviceModule(
        id: 'm2',
        name: 'Deck Blinds Control',
        type: ModuleType.blind,
        ipAddress: '192.168.1.102',
        status: ConnectionStatus.online,
        roomName: 'Deck',
        internalTempC: 29,
        tempMinC: 0,
        tempMaxC: 65,
        channels: [
          ChannelOutput(id: 'm2c1', name: 'Salon Blind', icon: Icons.blinds),
          ChannelOutput(id: 'm2c2', name: 'Cockpit Awning', icon: Icons.deck),
        ],
        inputs: [
          PhysicalInput(
              id: 'm2i1',
              label: 'Switch 1',
              mode: InputMode.associated,
              boundTo: 'Salon Blind'),
        ],
      ),
      DeviceModule(
        id: 'm3',
        name: 'Cabin Dimmer 12V',
        type: ModuleType.dimmerDc,
        ipAddress: '192.168.1.103',
        status: ConnectionStatus.online,
        roomName: 'Cabin',
        internalTempC: 31,
        tempMinC: 0,
        tempMaxC: 60,
        channels: [
          ChannelOutput(
              id: 'm3c1',
              name: 'Reading Light',
              icon: Icons.lightbulb_outline,
              brightness: 40),
          ChannelOutput(
              id: 'm3c2',
              name: 'Mood Light',
              icon: Icons.nightlight_round,
              brightness: 70),
          ChannelOutput(
              id: 'm3c3',
              name: 'Ceiling Light',
              icon: Icons.light,
              brightness: 0),
          ChannelOutput(
              id: 'm3c4',
              name: 'Courtesy Light',
              icon: Icons.wb_sunny_outlined,
              brightness: 20),
        ],
      ),
      DeviceModule(
        id: 'm4',
        name: 'Salon Dimmer 220V',
        type: ModuleType.dimmerAc,
        ipAddress: '192.168.1.104',
        status: ConnectionStatus.offline,
        roomName: 'Living Room',
        internalTempC: 38,
        tempMinC: 0,
        tempMaxC: 65,
        channels: [
          ChannelOutput(
              id: 'm4c1',
              name: 'Chandelier',
              icon: Icons.lightbulb,
              brightness: 15),
          ChannelOutput(
              id: 'm4c2',
              name: 'Wall Sconces',
              icon: Icons.light,
              brightness: 0),
          ChannelOutput(
              id: 'm4c3',
              name: 'Table Lamp',
              icon: Icons.emoji_objects,
              brightness: 30),
          ChannelOutput(
              id: 'm4c4',
              name: 'Accent Light',
              icon: Icons.highlight,
              brightness: 0),
        ],
      ),
      DeviceModule(
        id: 'm5',
        name: 'Engine Room Sensor',
        type: ModuleType.temperature,
        ipAddress: '192.168.1.105',
        status: ConnectionStatus.online,
        roomName: 'Engine Room',
        internalTempC: 62,
        tempMinC: 5,
        tempMaxC: 60,
      ),
      DeviceModule(
        id: 'm6',
        name: 'Bow Thruster Relay',
        type: ModuleType.relay,
        ipAddress: '192.168.1.106',
        status: ConnectionStatus.offline,
        roomName: 'Deck',
        internalTempC: 25,
        tempMinC: 0,
        tempMaxC: 70,
        channels: [
          ChannelOutput(id: 'm6c1', name: 'Anchor Light', icon: Icons.anchor),
          ChannelOutput(
              id: 'm6c2', name: 'Bow Floodlight', icon: Icons.wb_incandescent),
        ],
      ),
    ];

/// Tap-to-run scenarios and the manual dimming slider - brief section 2.4.
List<Scenario> mockScenarios() => [
      Scenario(
        id: 's1',
        name: 'Departure',
        icon: Icons.directions_boat,
        type: ScenarioType.tapToRun,
        roomName: 'Deck',
        showInHome: true,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Cabin Light',
              icon: Icons.lightbulb,
              isDimmerAction: false,
              turnOn: false),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Navigation Lights',
              icon: Icons.explore,
              isDimmerAction: false,
              turnOn: true),
        ],
      ),
      Scenario(
        id: 's2',
        name: 'Good Morning',
        icon: Icons.wb_sunny_outlined,
        type: ScenarioType.tapToRun,
        roomName: 'Bedroom',
        showInHome: true,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Reading Lamp',
              icon: Icons.menu_book,
              isDimmerAction: false,
              turnOn: true),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Kitchen Light',
              icon: Icons.light,
              isDimmerAction: false,
              turnOn: true),
          ScenarioAction(
              moduleName: 'Cabin Dimmer 12V',
              channelName: 'Mood Light',
              icon: Icons.nightlight_round,
              isDimmerAction: true,
              brightnessPct: 50),
        ],
      ),
      Scenario(
        id: 's3',
        name: 'Movie Night',
        icon: Icons.movie_outlined,
        type: ScenarioType.tapToRun,
        roomName: 'Living Room',
        showInHome: false,
        actions: [
          ScenarioAction(
              moduleName: 'Salon Dimmer 220V',
              channelName: 'Chandelier',
              icon: Icons.lightbulb,
              isDimmerAction: true,
              brightnessPct: 15),
          ScenarioAction(
              moduleName: 'Salon Dimmer 220V',
              channelName: 'Table Lamp',
              icon: Icons.emoji_objects,
              isDimmerAction: true,
              brightnessPct: 30),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Kitchen Light',
              icon: Icons.light,
              isDimmerAction: false,
              turnOn: false),
        ],
      ),
      Scenario(
        id: 's4',
        name: 'All Off',
        icon: Icons.power_settings_new,
        type: ScenarioType.tapToRun,
        roomName: 'No room',
        showInHome: true,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Cabin Light',
              icon: Icons.lightbulb,
              isDimmerAction: false,
              turnOn: false),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Kitchen Light',
              icon: Icons.light,
              isDimmerAction: false,
              turnOn: false),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Deck Floodlight',
              icon: Icons.wb_incandescent,
              isDimmerAction: false,
              turnOn: false),
          ScenarioAction(
              moduleName: 'Cabin Dimmer 12V',
              channelName: 'Reading Light',
              icon: Icons.lightbulb_outline,
              isDimmerAction: true,
              brightnessPct: 0),
        ],
      ),
      Scenario(
        id: 's5',
        name: 'Anchor Watch',
        icon: Icons.anchor,
        type: ScenarioType.tapToRun,
        roomName: 'Deck',
        showInHome: false,
        actions: [
          ScenarioAction(
              moduleName: 'Bow Thruster Relay',
              channelName: 'Anchor Light',
              icon: Icons.anchor,
              isDimmerAction: false,
              turnOn: true),
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Deck Floodlight',
              icon: Icons.wb_incandescent,
              isDimmerAction: false,
              turnOn: true),
        ],
      ),
      Scenario(
        id: 's6',
        name: 'Salon Mood Light',
        icon: Icons.tune,
        type: ScenarioType.manualSlider,
        roomName: 'Living Room',
        showInHome: true,
        sliderTargetName: 'Mood Light - Cabin Dimmer 12V',
        sliderValue: 70,
      ),
    ];

/// IF...THEN... smart automations - brief section 2.4.
List<Automation> mockAutomations() => [
      Automation(
        id: 'a1',
        name: 'Sunset Deck Lights',
        triggerType: AutomationTriggerType.time,
        triggerSummary: 'Every day at 20:00',
        enabled: true,
        scheduleHour: 20,
        scheduleMinute: 0,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Deck Floodlight',
              icon: Icons.wb_incandescent,
              isDimmerAction: false,
              turnOn: true),
          ScenarioAction(
              moduleName: 'Bow Thruster Relay',
              channelName: 'Anchor Light',
              icon: Icons.anchor,
              isDimmerAction: false,
              turnOn: true),
        ],
      ),
      Automation(
        id: 'a2',
        name: 'Bilge Pump Alert',
        triggerType: AutomationTriggerType.deviceState,
        triggerSummary: 'When Bilge Pump turns ON',
        enabled: true,
        watchChannelName: 'Bilge Pump',
        watchState: true,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Cabin Light',
              icon: Icons.lightbulb,
              isDimmerAction: false,
              turnOn: true),
        ],
      ),
      Automation(
        id: 'a3',
        name: 'Night Security Light',
        triggerType: AutomationTriggerType.time,
        triggerSummary: 'Every day at 22:30',
        enabled: false,
        scheduleHour: 22,
        scheduleMinute: 30,
        actions: [
          ScenarioAction(
              moduleName: 'Main Cabin Relay',
              channelName: 'Deck Floodlight',
              icon: Icons.wb_incandescent,
              isDimmerAction: false,
              turnOn: true),
        ],
      ),
    ];

/// 30-day rolling event history - brief section 2.4.
List<EventLogEntry> mockEventLog() => [
      EventLogEntry(
          time: _ago(const Duration(minutes: 10)),
          title: 'Cabin Light turned ON',
          subtitle: 'Departure scenario'),
      EventLogEntry(
          time: _ago(const Duration(minutes: 11)),
          title: 'Navigation Lights turned ON',
          subtitle: 'Departure scenario'),
      EventLogEntry(
          time: _ago(const Duration(hours: 2)),
          title: 'Reading Lamp turned ON',
          subtitle: 'Good Morning scenario'),
      EventLogEntry(
          time: _ago(const Duration(hours: 2, minutes: 5)),
          title: 'Kitchen Light turned ON',
          subtitle: 'Good Morning scenario'),
      EventLogEntry(
          time: _ago(const Duration(days: 1)),
          title: 'Deck Floodlight turned OFF',
          subtitle: 'Manual control'),
      EventLogEntry(
          time: _ago(const Duration(days: 1, hours: 2)),
          title: 'Mood Light set to 70%',
          subtitle: 'Manual control'),
      EventLogEntry(
          time: _ago(const Duration(days: 2)),
          title: 'Anchor Light turned ON',
          subtitle: 'Anchor Watch scenario'),
      EventLogEntry(
          time: _ago(const Duration(days: 3)),
          title: 'All outputs turned OFF',
          subtitle: 'All Off scenario'),
      EventLogEntry(
          time: _ago(const Duration(days: 5)),
          title: 'Bilge Pump turned ON',
          subtitle: 'Physical input - Switch 3'),
      EventLogEntry(
          time: _ago(const Duration(days: 6)),
          title: 'Cabin Light turned ON',
          subtitle: 'Bilge Pump Alert automation'),
      EventLogEntry(
          time: _ago(const Duration(days: 10)),
          title: 'Salon Dimmer 220V went offline',
          subtitle: 'System'),
      EventLogEntry(
          time: _ago(const Duration(days: 20)),
          title: 'Chandelier set to 15%',
          subtitle: 'Movie Night scenario'),
    ];

/// System Status error/event log - brief section I, point 2.
List<StatusLogEntry> mockStatusLog() => [
      StatusLogEntry(
          time: _ago(const Duration(minutes: 1)),
          moduleName: 'Engine Room Sensor',
          message: 'Internal temperature exceeded threshold (62.0°C)',
          isAlert: true),
      StatusLogEntry(
          time: _ago(const Duration(minutes: 30)),
          moduleName: 'Salon Dimmer 220V',
          message: 'Module went offline',
          isAlert: true),
      StatusLogEntry(
          time: _ago(const Duration(hours: 2)),
          moduleName: 'Bow Thruster Relay',
          message: 'Module went offline',
          isAlert: true),
      StatusLogEntry(
          time: _ago(const Duration(days: 1)),
          moduleName: 'Salon Dimmer 220V',
          message: 'Module reconnected',
          isAlert: false),
      StatusLogEntry(
          time: _ago(const Duration(days: 3)),
          moduleName: 'Bow Thruster Relay',
          message: 'Module reconnected',
          isAlert: false),
      StatusLogEntry(
          time: _ago(const Duration(days: 4)),
          moduleName: 'Bow Thruster Relay',
          message: 'Module went offline',
          isAlert: true),
    ];

/// Icon palette offered when naming/customizing an output - brief 2.2.
const List<IconData> kChannelIconChoices = [
  Icons.lightbulb,
  Icons.lightbulb_outline,
  Icons.light,
  Icons.nightlight_round,
  Icons.wb_incandescent,
  Icons.wb_sunny_outlined,
  Icons.tv,
  Icons.kitchen,
  Icons.water_drop,
  Icons.water,
  Icons.ac_unit,
  Icons.blinds,
  Icons.deck,
  Icons.anchor,
  Icons.directions_boat,
  Icons.power,
  Icons.electrical_services,
  Icons.outdoor_grill,
  Icons.garage,
  Icons.emoji_objects,
];
