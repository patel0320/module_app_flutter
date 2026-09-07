import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/module.dart';
import '../../data/models/scenario.dart';

/// Number of offline modules, driving the Home alert banner.
final homeOfflineAlertProvider = Provider<int>((ref) {
  final modules = ref.watch(moduleRepositoryProvider);
  return modules.where((m) => m.status == ModuleStatus.offline).length;
});

/// Scenarios flagged 'Show in Home', in stored order, paired with the room
/// name they belong to for card display. Replacement for a scenario
/// repository as soon as the scenario engine state lands.
final homeQuickActionsProvider = Provider<List<(Scenario, String)>>((ref) {
  return const [
    (
      Scenario(
        id: 's-departure',
        locationId: 'loc1',
        roomId: 3,
        name: 'Departure',
        icon: 'departure',
        showInHome: true,
        type: ScenarioType.manual,
        actions: [
          ScenarioAction(
            id: 's1-a1',
            order: 1,
            type: ScenarioActionType.setRelay,
            channelId: 'm1c1',
            targetState: true,
          ),
          ScenarioAction(
            id: 's1-a2',
            order: 2,
            type: ScenarioActionType.setBrightness,
            channelId: 'm3c2',
            brightnessPct: 60,
          ),
        ],
      ),
      'Deck',
    ),
    (
      Scenario(
        id: 's-dim-living',
        locationId: 'loc1',
        roomId: 1,
        name: 'Living Room',
        icon: 'living',
        showInHome: true,
        type: ScenarioType.slider,
        actions: [
          ScenarioAction(
            id: 's2-a1',
            order: 1,
            type: ScenarioActionType.setBrightness,
            channelId: 'm2c1',
            brightnessPct: 40,
          ),
        ],
      ),
      'Living Room',
    ),
  ];
});

/// (module, currentTemperature) pairs for temperature modules.
final homeTemperatureProvider = Provider<List<(Module, double)>>((ref) {
  final modules = ref.watch(moduleRepositoryProvider);
  final temperatures = <(Module, double)>[];
  for (final m in modules) {
    if (m.type == ModuleType.temperature) {
      temperatures.add((m, 22.4));
    }
  }
  return temperatures;
});
