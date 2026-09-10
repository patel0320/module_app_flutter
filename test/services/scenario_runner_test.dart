// Tests for the scenario runner's action resolution and tracing path.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/module_store.dart';
import 'package:soleux_device_manager/services/scenario_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScenarioRunner', () {
    test('flags an unknown module as a failed action', () async {
      final runner = ScenarioRunner.shared;
      final result = await runner.run(Scenario(
        id: 's1',
        name: 'Test',
        icon: Icons.play_arrow,
        type: ScenarioType.tapToRun,
        actions: [
          ScenarioAction(
            moduleName: 'No Such Module',
            channelName: 'X',
            icon: Icons.power,
            isDimmerAction: false,
            turnOn: true,
          ),
        ],
      ));

      expect(result.actions, hasLength(1));
      expect(result.actions.first.success, isFalse);
      expect(result.actions.first.detail, contains('not found'));
      expect(result.failed, 1);
    });

    test('resolves a seeded module but reports not-connected', () async {
      await ModuleStore.shared.init();
      final runner = ScenarioRunner.shared;

      // The very first run seeds the demo fleet (Main Cabin Relay has
      // 'Cabin Light' at index 0); with no live socket, dispatch is reported
      // as failed with a "not connected" reason.
      final result = await runner.run(Scenario(
        id: 's2',
        name: 'Test Relay',
        icon: Icons.play_arrow,
        type: ScenarioType.tapToRun,
        actions: [
          ScenarioAction(
            moduleName: 'Main Cabin Relay',
            channelName: 'Cabin Light',
            icon: Icons.lightbulb,
            isDimmerAction: false,
            turnOn: true,
          ),
        ],
      ));

      expect(result.actions, hasLength(1));
      // Not connected (no live socket in tests) => reported as failed.
      expect(result.actions.first.success, isFalse);
      expect(result.actions.first.detail, contains('not connected'));
    });

    test('resolves an input action by input name', () async {
      await ModuleStore.shared.init();
      final runner = ScenarioRunner.shared;

      final result = await runner.run(Scenario(
        id: 's3',
        name: 'Test Input',
        icon: Icons.touch_app_outlined,
        type: ScenarioType.tapToRun,
        actions: [
          ScenarioAction(
            moduleName: 'Main Cabin Relay',
            channelName: '',
            icon: Icons.touch_app_outlined,
            isDimmerAction: false,
            isInputAction: true,
            inputName: 'Switch 2',
            inputState: InputActionState.pulse,
          ),
        ],
      ));

      expect(result.actions, hasLength(1));
      // Input resolved on the seeded module; no live socket => failed,
      // "not connected" (not "input not found").
      expect(result.actions.first.success, isFalse);
      expect(result.actions.first.detail, contains('not connected'));
    });

    test('reports an unknown input as a failed action', () async {
      await ModuleStore.shared.init();
      final runner = ScenarioRunner.shared;

      final result = await runner.run(Scenario(
        id: 's4',
        name: 'Test Bad Input',
        icon: Icons.touch_app_outlined,
        type: ScenarioType.tapToRun,
        actions: [
          ScenarioAction(
            moduleName: 'Main Cabin Relay',
            channelName: '',
            icon: Icons.touch_app_outlined,
            isDimmerAction: false,
            isInputAction: true,
            inputName: 'No Such Input',
            inputState: InputActionState.on,
          ),
        ],
      ));

      expect(result.actions, hasLength(1));
      expect(result.actions.first.success, isFalse);
      expect(result.actions.first.detail, contains('Input "No Such Input" not found'));
    });
  });
}
