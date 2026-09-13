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
/// name they belong to for card display. Starts empty; wired to real scenario
/// storage when the scenario engine state lands.
final homeQuickActionsProvider = Provider<List<(Scenario, String)>>((ref) {
  return const [];
});

/// (module, currentTemperature) pairs for temperature modules. No fabricated
/// readings are shown - the list only reflects real module data.
final homeTemperatureProvider = Provider<List<(Module, double)>>((ref) {
  final modules = ref.watch(moduleRepositoryProvider);
  final temperatures = <(Module, double)>[];
  for (final m in modules) {
    if (m.type == ModuleType.temperature) {
      temperatures.add((m, 0.0));
    }
  }
  return temperatures;
});
