// Tests for the app-wide event-log store (tracing + 30-day retention).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:module_app_flutter/models/models.dart';
import 'package:module_app_flutter/services/event_log_store.dart';

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

      expect(store.entries.first.title, 'Automation triggered: Sunset Deck Lights');
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

    test('clears the whole history', () async {
      final store = EventLogStore.forTesting();
      await store.init();
      await store.clear();
      expect(store.entries, isEmpty);
    });
  });
}
