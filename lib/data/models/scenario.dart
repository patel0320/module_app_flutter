import 'channel.dart';

enum ScenarioType { manual, slider, automation }

enum ScenarioTriggerSource { time, deviceState }

enum ScenarioActionType { setRelay, setBrightness, blindMove }

class ScenarioAction {
  final String id;
  final int order;
  final ScenarioActionType type;
  final String channelId;
  final bool? targetState; // relay on/off.
  final int? brightnessPct; // 0-100 dimmer target.
  final BlindDirection? blindDir;

  const ScenarioAction({
    required this.id,
    required this.order,
    required this.type,
    required this.channelId,
    this.targetState,
    this.brightnessPct,
    this.blindDir,
  });
}

class AutomationTrigger {
  final ScenarioTriggerSource source;
  final DateTime? scheduledAt; // time-based.
  final String? watchChannelId; // device-state based.
  final ChannelState? watchState;

  const AutomationTrigger({
    required this.source,
    this.scheduledAt,
    this.watchChannelId,
    this.watchState,
  });
}

class Scenario {
  final String id;
  final String locationId;
  final int? roomId;
  final String name;
  final String? icon;
  final int order;
  final bool showInHome;
  final ScenarioType type;
  final List<ScenarioAction> actions;
  final AutomationTrigger? automation;

  const Scenario({
    required this.id,
    required this.locationId,
    this.roomId,
    required this.name,
    this.icon,
    this.order = 0,
    this.showInHome = false,
    this.type = ScenarioType.manual,
    this.actions = const [],
    this.automation,
  });
}
