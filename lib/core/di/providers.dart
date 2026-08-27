import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:module_app_flutter/core/config/env.dart';
import 'package:module_app_flutter/core/drivers/module_driver.dart';
import 'package:module_app_flutter/core/transport/mock_transport.dart';
import 'package:module_app_flutter/core/transport/transport.dart';
import 'package:module_app_flutter/data/models/channel.dart';
import 'package:module_app_flutter/data/models/module.dart';
import 'package:module_app_flutter/features/configuration/drivers/driver_factory.dart';

/// App environment + config.
final appConfigProvider = Provider((ref) => Env.config);

/// In-memory registry of discovered modules + their drivers.
/// Replace the MockTransport wire-up with the LAN/MQTT factories once the real
/// protocol contracts are frozen (Stage 3/4) — see setup.md §5.
final moduleRepositoryProvider =
    StateNotifierProvider<ModuleRepository, List<Module>>((ref) {
  return ModuleRepository(factory: const DriverFactory());
});

final moduleDriversProvider = Provider<Map<String, ModuleDriver>>((ref) {
  final repo = ref.watch(moduleRepositoryProvider.notifier);
  return repo.drivers;
});

class ModuleRepository extends StateNotifier<List<Module>> {
  final DriverFactory factory;
  final Map<String, ModuleDriver> drivers = {};
  final Map<String, List<Channel>> channelsByModule = {};

  ModuleRepository({required this.factory}) : super([]) {
    _seedDemoModules();
  }

  void _seedDemoModules() {
    // Demo data so the scaffold runs without hardware. Remove once discovery is live.
    const relay = Module(
      id: 'm1',
      type: ModuleType.relay,
      name: 'Relay Module 8',
      ip: '192.168.1.10',
      status: ModuleStatus.online,
    );
    const dimmer = Module(
      id: 'm2',
      type: ModuleType.dcDimmer,
      name: 'DC Dimmer 4',
      ip: '192.168.1.11',
      status: ModuleStatus.online,
    );
    const temp = Module(
      id: 'm3',
      type: ModuleType.temperature,
      name: 'Temperature Module',
      ip: '192.168.1.12',
      status: ModuleStatus.online,
    );

    final relayChannels = List<Channel>.generate(
        8,
        (i) => Channel(
            id: 'm1c$i', moduleId: 'm1', index: i, name: 'Output ${i + 1}'));
    final dimmerChannels = List<Channel>.generate(
        4,
        (i) => Channel(
            id: 'm2c$i',
            moduleId: 'm2',
            index: i,
            name: 'Light ${i + 1}',
            brightness: 0));
    final tempChannels = [
      const Channel(
          id: 'm3c0', moduleId: 'm3', index: 0, name: 'Internal Temperature'),
    ];

    channelsByModule['m1'] = relayChannels;
    channelsByModule['m2'] = dimmerChannels;
    channelsByModule['m3'] = tempChannels;

    final mock = MockTransport();
    drivers['m1'] = factory.create(relay, mock, relayChannels);
    drivers['m2'] = factory.create(dimmer, MockTransport(), dimmerChannels);
    drivers['m3'] = factory.create(temp, mock, tempChannels);

    state = [relay, dimmer, temp];
  }

  List<Channel> channelsOf(String moduleId) =>
      channelsByModule[moduleId] ?? const [];

  void addDiscoveredModule(
      Module module, List<Channel> channels, Transport transport) {
    channelsByModule[module.id] = channels;
    drivers[module.id] = factory.create(module, transport, channels);
    state = [...state, module];
  }
}
