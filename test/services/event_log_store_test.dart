// Tests for the app-wide event-log store (tracing + 30-day retention).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/event_log_store.dart';
import 'package:soleux_device_manager/services/scenario_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EventLogStore', () {
    test('loads, records and persists new events', () async {
      final store = EventLogStore.forTesting();
      await store.init();
      expect(store.loaded, isTrue);
      // Seeded demo history is present on the very first run.
      expect(store.entries, isNotEmpty);

      final before = store.entries.length;
      await store.recordModuleAction(
        moduleName: 'Main Cabin Relay',
        outputName: 'Cabin Light',
        on: true,
      );
      expect(store.entries.length, before + 1);
      expect(store.entries.first.title, 'Cabin Light turned ON');
    });

    test('records scenario and automation runs', () async {
      final store = EventLogStore.forTesting();
      await store.init();

      await store.recordScenario(scenarioName: 'Departure');
      await store.recordAutomation(automationName: 'Sunset Deck Lights');

      expect(store.entries.first.title,
          'Automation triggered: Sunset Deck Lights');
      expect(store.entries[1].title, 'Scenario ran: Departure');
    });

    test('drops entries older than the 30-day retention window', () async {
      final store = EventLogStore.forTesting();
      await store.init();

      // Seed an entry just inside the window and one just outside it.
      await store.record(EventLogEntry(
        time: DateTime.now().subtract(const Duration(days: 29)),
        title: 'Recent',
        subtitle: 'ok',
      ));
      await store.record(EventLogEntry(
        time: DateTime.now().subtract(const Duration(days: 45)),
        title: 'Ancient',
        subtitle: 'pruned',
      ));

      expect(store.entries.any((e) => e.title == 'Recent'), isTrue,
          reason: 'Within-window entries must survive');
      expect(store.entries.any((e) => e.title == 'Ancient'), isFalse,
          reason: 'Entries older than 30 days must be pruned');
    });

    test('records per-action scenario traces with success/failure', () async {
      final store = EventLogStore.forTesting();
      await store.init();

      await store.recordScenarioResult(const ScenarioRunResult(
        scenarioName: 'Departure',
        actions: [
          ScenarioActionResult(
            description: 'Cabin Light -> ON',
            success: true,
            detail: 'ACK',
          ),
          ScenarioActionResult(
            description: 'Deck Floodlight -> ON',
            success: false,
            detail: 'not connected',
          ),
        ],
      ));

      expect(store.entries.first.title, contains('Failed: Deck Floodlight'));
      expect(store.entries.first.subtitle, contains('Scenario: Departure'));
      expect(store.entries[1].title, contains('Success: Cabin Light'));
    });

    test('clears the whole history', () async {
      final store = EventLogStore.forTesting();
      await store.init();
      await store.clear();
      expect(store.entries, isEmpty);
    });
  });
}
