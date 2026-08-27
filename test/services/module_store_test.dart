// Tests for the app-wide module store (single source of truth + live updates).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/module_store.dart';

DeviceModule _module(String id, {String name = 'Relay'}) => DeviceModule(
      id: id,
      name: name,
      type: ModuleType.relay,
      ipAddress: '192.168.1.$id',
      status: ConnectionStatus.offline,
      roomName: 'Cabin',
      internalTempC: 30,
      channels: [
        ChannelOutput(id: '${id}c1', name: 'Cabin Light', icon: Icons.power),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ModuleStore', () {
    test('populates asynchronously and notifies listeners', () async {
      // A fresh store is used in each test for isolation.
      final store = ModuleStore.forTesting();
      var notified = 0;
      store.addListener(() => notified++);

      await store.init();
      expect(store.loaded, isTrue);
      // The repository seeds demo modules on a first empty run.
      expect(store.modules, isNotEmpty);
      expect(notified, greaterThanOrEqualTo(1));
    });

    test('upsert adds and replaces by id', () async {
      final store = ModuleStore.forTesting();
      await store.init();

      final fresh = _module('z1', name: 'New Relay');
      await store.upsert(fresh);
      expect(store.byId('z1')!.name, 'New Relay');

      await store.upsert(_module('z1', name: 'Renamed'));
      expect(store.modules.where((m) => m.id == 'z1'), hasLength(1));
      expect(store.byId('z1')!.name, 'Renamed');
    });

    test('upsert preserves user-defined channel names when re-adding an id',
        () async {
      final store = ModuleStore.forTesting();
      await store.init();

      final seeded = DeviceModule(
        id: 'u1',
        name: 'Main Relay',
        type: ModuleType.relay,
        ipAddress: '192.168.1.20',
        status: ConnectionStatus.offline,
        roomName: 'Cabin',
        internalTempC: 30,
        channels: [
          ChannelOutput(
              id: 'u1c1', name: 'Cabin Light', icon: Icons.lightbulb),
        ],
      );
      await store.upsert(seeded);

      // A freshly re-discovered copy carries generic default names; merging it
      // back in must not reset the user-defined channel name/icon.
      final rediscovered = DeviceModule(
        id: 'u1',
        name: 'PDU-DUMMY',
        type: ModuleType.relay,
        ipAddress: '192.168.1.20',
        status: ConnectionStatus.online,
        roomName: 'Unassigned',
        internalTempC: 25,
        channels: [
          ChannelOutput(
              id: 'new-r0', name: 'Output 1', icon: Icons.power, isOn: true),
        ],
      );
      await store.upsert(rediscovered);

      final kept = store.byId('u1')!;
      expect(kept.channels.single.name, 'Cabin Light');
      expect(kept.channels.single.icon, Icons.lightbulb);
      expect(kept.channels.single.id, 'u1c1');
      expect(kept.channels.single.isOn, isTrue); // fresh state adopted
      expect(kept.status, ConnectionStatus.online);
    });

    test('update mutates an existing module and notifies', () async {
      final store = ModuleStore.forTesting();
      await store.init();
      await store.upsert(_module('w1'));
      await store.update('w1', (m) => m.status = ConnectionStatus.online);
      expect(store.byId('w1')!.status, ConnectionStatus.online);
    });

    test('remove deletes a module by id', () async {
      final store = ModuleStore.forTesting();
      await store.init();
      await store.upsert(_module('v1'));
      await store.remove('v1');
      expect(store.byId('v1'), isNull);
    });
  });
}
