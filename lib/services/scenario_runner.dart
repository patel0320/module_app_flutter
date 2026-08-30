// lib/services/scenario_runner.dart
//
// Executes the actions of a tap-to-run scenario against the live command
// service and reports the per-action outcome so the event history can log not
// just that a scenario ran but the detail and success/failure of each action
// (brief section 2.4).
//
// Actions are resolved by module / output name against the app-wide module
// store, then dispatched through each module's persistent [ModuleCommandService].
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'module_status/module_status_service.dart';
import 'module_store.dart';

/// Outcome of a single scenario action dispatch.
@immutable
class ScenarioActionResult {
  /// Human-readable description of the action (e.g. `Cabin Light -> ON`).
  final String description;

  /// True when the module acknowledged the command with `OK`.
  final bool success;

  /// Extra detail (target module/output, failure reason). Populated on failure
  /// and on success with a minimal confirmation.
  final String detail;

  const ScenarioActionResult({
    required this.description,
    required this.success,
    required this.detail,
  });

  @override
  String toString() => '$description [${success ? 'OK' : 'FAILED'}]';
}

/// Result of running a whole scenario.
@immutable
class ScenarioRunResult {
  final String scenarioName;
  final List<ScenarioActionResult> actions;

  const ScenarioRunResult({required this.scenarioName, required this.actions});

  int get succeeded => actions.where((a) => a.success).length;
  int get failed => actions.length - succeeded;
  String get summary => failed == 0
      ? 'All ${actions.length} action(s) OK'
      : '$failed of ${actions.length} action(s) failed';
}

class ScenarioRunner {
  ScenarioRunner._();

  /// App-wide shared instance used by screens that run scenarios.
  static ScenarioRunner shared = ScenarioRunner._();

  /// Runs every action in [scenario] sequentially, collecting per-action
  /// results. Never throws - each unresolvable action becomes a failed result.
  Future<ScenarioRunResult> run(Scenario scenario) async {
    await ModuleStore.shared.init();
    final results = <ScenarioActionResult>[];
    for (final action in scenario.actions) {
      results.add(await _runAction(scenario, action));
    }
    return ScenarioRunResult(scenarioName: scenario.name, actions: results);
  }

  Future<ScenarioActionResult> _runAction(
      Scenario scenario, ScenarioAction action) async {
    final description = '${action.moduleName}: ${action.summary}';

    final module = _resolveModule(action.moduleName);
    if (module == null) {
      return ScenarioActionResult(
        description: description,
        success: false,
        detail: 'Module "${action.moduleName}" not found in this location',
      );
    }

    final index =
        module.channels.indexWhere((c) => c.name == action.channelName);
    if (index < 0) {
      return ScenarioActionResult(
        description: description,
        success: false,
        detail: 'Output "${action.channelName}" not found on ${module.name}',
      );
    }
    final channel = module.channels[index];

    final service = ModuleStatusService.shared;
    final connected = (service.commandServiceFor(module.id)?.isConnected ??
            service.jsonCommandServiceFor(module.id)?.isConnected) ??
        false;
    if (!connected) {
      return ScenarioActionResult(
        description: description,
        success: false,
        detail: '${module.name} is not connected',
      );
    }

    try {
      final bool ok = switch ((action.isDimmerAction, action.turnOn)) {
        (true, _) => await service.sendLegacyCommand(
            module.id, 'AT+BRIGH:$index:${action.brightnessPct}\r'),
        (false, true) => await service.turnOnOutput(module.id, index),
        (false, false) => await service.turnOffOutput(module.id, index),
      };
      return ScenarioActionResult(
        description: description,
        success: ok,
        detail: ok
            ? 'ACK on ${channel.name}'
            : 'Command rejected by ${module.name}',
      );
    } catch (e) {
      return ScenarioActionResult(
        description: description,
        success: false,
        detail: 'Command failed on ${module.name}: $e',
      );
    }
  }

  DeviceModule? _resolveModule(String moduleName) {
    for (final m in ModuleStore.shared.modules) {
      if (m.name.toLowerCase() == moduleName.toLowerCase()) return m;
    }
    return null;
  }
}
