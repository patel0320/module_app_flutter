// Tests for the Notification History store: real OFFLINE / RESTORED /
// FIRMWARE events are recorded, persisted and pruned.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/status_log_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StatusLogStore', () {
    test('starts empty (no mock seeding) and records offline events', () async {
      final store = StatusLogStore.forTesting();
      await store.init();
      expect(store.entries, isEmpty, reason: 'must not seed demo history');

      await store.recordOffline();
      expect(store.entries, hasLength(1));
      expect(store.entries.first.type, StatusLogType.offline);
      expect(store.entries.first.isAlert, isTrue);
    });

    test('records restored and firmware events with localized messages',
        () async {
      final store = StatusLogStore.forTesting();
      await store.init();

      await store.recordRestored();
      expect(store.entries.first.type, StatusLogType.restored);
      expect(store.entries.first.isAlert, isFalse);

      await store.recordFirmwareReported('7.14');
      expect(store.entries.first.type, StatusLogType.firmware);
      expect(store.entries.first.message, contains('7.14'));

      await store.recordFirmwareChanged('7.13', '7.14');
      expect(store.entries.first.message, contains('7.13'));
      expect(store.entries.first.message, contains('7.14'));
    });

    test('returns entries newest-first', () async {
      final store = StatusLogStore.forTesting();
      await store.init();
      for (var i = 0; i < 3; i++) {
        await store.recordOffline();
      }
      final times = store.entries.map((e) => e.time).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i - 1].isAfter(times[i]), isTrue,
            reason: 'most recent entry must come first');
      }
    });

    test('survives persistence across store instances', () async {
      final first = StatusLogStore.forTesting();
      await first.init();
      await first.recordOffline();

      final second = StatusLogStore.forTesting();
      await second.init();
      expect(second.entries, hasLength(1));
      expect(second.entries.first.type, StatusLogType.offline);
    });

    test('drops entries older than the 30-day retention window', () async {
      final store = StatusLogStore.forTesting();
      await store.init();

      await store.record(StatusLogEntry(
        time: DateTime.now().subtract(const Duration(days: 29)),
        type: StatusLogType.restored,
        message: 'Device is online again',
      ));
      await store.record(StatusLogEntry(
        time: DateTime.now().subtract(const Duration(days: 45)),
        type: StatusLogType.offline,
        message: 'Heartbeat or connection was lost',
      ));

      expect(store.entries.any((e) => e.type == StatusLogType.restored), isTrue,
          reason: 'Within-window entries must survive');
      expect(store.entries.any((e) => e.type == StatusLogType.offline), isFalse,
          reason: 'Entries older than 30 days must be pruned');
    });

    test('clears the whole history', () async {
      final store = StatusLogStore.forTesting();
      await store.init();
      await store.recordOffline();
      await store.clear();
      expect(store.entries, isEmpty);
    });
  });
}
