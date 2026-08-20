import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/module.dart';
import '../../data/models/scenario.dart';

/// Number of offline modules, driving the Home alert banner.
final homeOfflineAlertProvider = Provider<int>((ref) {
  final modules = ref.watch(moduleRepositoryProvider);
  return modules.where((m) => m.status == ModuleStatus.offline).length;
});

/// Scenarios flagged 'Show in Home', in stored order. Replacement for a
/// scenario repository as soon as the scenario engine state lands.
final homeQuickActionsProvider = Provider<List<Scenario>>((ref) {
  return const [
    Scenario(
      id: 's-departure',
      locationId: 'loc1',
      name: 'Departure',
      icon: 'departure',
      showInHome: true,
      type: ScenarioType.manual,
    ),
    Scenario(
      id: 's-dim-living',
      locationId: 'loc1',
      name: 'Living Room',
      icon: 'living',
      showInHome: true,
      type: ScenarioType.slider,
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
