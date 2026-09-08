// Tests for the notification monitor: state changes in the module store
// surface as alerts that respect the notification preferences.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/module_store.dart';
import 'package:soleux_device_manager/services/notification_monitor.dart';
import 'package:soleux_device_manager/services/settings_store.dart';
import 'package:soleux_device_manager/services/status_log_store.dart';

DeviceModule _module(String id,
        {ConnectionStatus status = ConnectionStatus.online,
        double tempC = 30,
        String? firmware}) =>
    DeviceModule(
      id: id,
      name: 'Relay $id',
      type: ModuleType.relay,
      ipAddress: '192.168.1.$id',
      status: status,
      roomName: 'Cabin',
      internalTempC: tempC,
      tempMinC: 0,
      tempMaxC: 60,
      firmware: firmware,
      channels: [
        ChannelOutput(id: '${id}c1', name: 'Cabin Light', icon: Icons.power),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ModuleStore> storeWith(List<DeviceModule> modules) async {
    final store = ModuleStore.forTesting();
    await store.init();
    await store.replaceAll(modules);
    return store;
  }

  group('NotificationMonitor baseline', () {
    test('does not alert for the initial (seed) state', () async {
      final store =
          await storeWith([_module('m1', status: ConnectionStatus.offline)]);
      final monitor = NotificationMonitor.forTesting(store,
          settleDuration: const Duration(milliseconds: 20));
      monitor.start();
      await store.commit();

      expect(monitor.notificationCount, 0);
      monitor.dispose();
    });
  });

  group('NotificationMonitor module status', () {
    test('alerts once when a module goes offline (change settles)', () async {
      final store =
          await storeWith([_module('m1', status: ConnectionStatus.online)]);
      final monitor = NotificationMonitor.forTesting(store,
          settleDuration: const Duration(milliseconds: 20));
      monitor.start();
      await store.commit();
      expect(monitor.notificationCount, 0);

      await store.update('m1', (m) => m.status = ConnectionStatus.offline);
      // Still unconfirmed within the settle window.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(monitor.notificationCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(monitor.notificationCount, 1);
      monitor.dispose();
    });

    test('drops a transition that reverts before the settle window', () async {
      final store =
          await storeWith([_module('m2', status: ConnectionStatus.online)]);
      final monitor = NotificationMonitor.forTesting(store,
          settleDuration: const Duration(milliseconds: 30));
      monitor.start();
      await store.commit();

      await store.update('m2', (m) => m.status = ConnectionStatus.offline);
      await store.update('m2', (m) => m.status = ConnectionStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(monitor.notificationCount, 0);
      monitor.dispose();
    });

    test('records OFFLINE / RESTORED history entries for settled transitions',
        () async {
      final store =
          await storeWith([_module('m1', status: ConnectionStatus.online)]);
      final log = StatusLogStore.forTesting();
      await log.init();
      final monitor = NotificationMonitor.forTesting(store,
          settleDuration: const Duration(milliseconds: 20), statusLog: log);
      await log.clear();
      monitor.start();
      await store.commit();

      await store.update('m1', (m) => m.status = ConnectionStatus.offline);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(log.entries.first.type, StatusLogType.offline);

      await store.update('m1', (m) => m.status = ConnectionStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(log.entries.first.type, StatusLogType.restored);
      expect(log.entries, hasLength(2));
      monitor.dispose();
    });

    test('records FIRMWARE history on a version change', () async {
      final store = await storeWith(
          [_module('f1', status: ConnectionStatus.online, firmware: '7.13')]);
      final log = StatusLogStore.forTesting();
      await log.init();
      await log.clear();
      final monitor = NotificationMonitor.forTesting(store,
          settleDuration: const Duration(milliseconds: 20), statusLog: log);
      monitor.start();
      await store.commit();
      expect(log.entries, isEmpty);

      await store.update('f1', (m) => m.firmware = '7.14');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(log.entries.first.type, StatusLogType.firmware);
      expect(log.entries.first.message, contains('7.13'));
      expect(log.entries.first.message, contains('7.14'));
      monitor.dispose();
    });
  });

  group('NotificationMonitor temperature', () {
    test('alerts once when the module leaves its temperature range', () async {
      final store = await storeWith(
          [_module('t1', status: ConnectionStatus.online, tempC: 30)]);
      final monitor = NotificationMonitor.forTesting(store);
      monitor.start();
      await store.commit();
      expect(monitor.notificationCount, 0);

      await store.update('t1', (m) => m.internalTempC = 71);
      expect(monitor.notificationCount, 1);
      monitor.dispose();
    });

    test('does not alert while the module is offline', () async {
      final store = await storeWith(
          [_module('t2', status: ConnectionStatus.offline, tempC: 30)]);
      final monitor = NotificationMonitor.forTesting(store);
      monitor.start();
      await store.commit();

      await store.update('t2', (m) => m.internalTempC = 71);
      expect(monitor.notificationCount, 0);
      monitor.dispose();
    });
  });

  group('NotificationMonitor output left ON', () {
    test('alerts when an output stays ON past the threshold', () async {
      final store =
          await storeWith([_module('o1', status: ConnectionStatus.online)]);
      final monitor =
          NotificationMonitor.forTesting(store, outputThreshold: Duration.zero);
      monitor.start();
      await store.commit();
      expect(monitor.notificationCount, 0);

      await store.update('o1', (m) => m.channels.first.isOn = true);
      expect(monitor.notificationCount, 1);

      // A second evaluation must not double-alert for the same episode.
      await store.commit();
      expect(monitor.notificationCount, 1);
      monitor.dispose();
    });

    test('resets when the output is turned off', () async {
      final store =
          await storeWith([_module('o2', status: ConnectionStatus.online)]);
      final monitor =
          NotificationMonitor.forTesting(store, outputThreshold: Duration.zero);
      monitor.start();
      await store.commit();

      await store.update('o2', (m) => m.channels.first.isOn = true);
      expect(monitor.notificationCount, 1);

      await store.update('o2', (m) => m.channels.first.isOn = false);
      await store.update('o2', (m) => m.channels.first.isOn = true);
      expect(monitor.notificationCount, 2);
      monitor.dispose();
    });
  });

  group('NotificationMonitor output threshold from SettingsStore', () {
    test('defaults to 12 hours when no override is provided', () async {
      await SettingsStore.shared.init();
      await SettingsStore.shared.setOutputOnThresholdHours(12);
      final store =
          await storeWith([_module('d1', status: ConnectionStatus.online)]);
      final monitor = NotificationMonitor.forTesting(store);
      expect(monitor.outputThreshold, const Duration(hours: 12));
      monitor.dispose();
    });

    test('reflects the user-configured threshold', () async {
      await SettingsStore.shared.init();
      await SettingsStore.shared.setOutputOnThresholdHours(6);
      final store =
          await storeWith([_module('d2', status: ConnectionStatus.online)]);
      final monitor = NotificationMonitor.forTesting(store);
      expect(monitor.outputThreshold, const Duration(hours: 6));
      monitor.dispose();
    });

    test('clamps threshold input to 1..168 hours', () async {
      await SettingsStore.shared.init();
      await SettingsStore.shared.setOutputOnThresholdHours(0);
      expect(SettingsStore.shared.outputOnThresholdHours, 1);
      await SettingsStore.shared.setOutputOnThresholdHours(500);
      expect(SettingsStore.shared.outputOnThresholdHours, 168);
    });
  });
}
