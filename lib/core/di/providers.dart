import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:soleux_device_manager/core/config/env.dart';
import 'package:soleux_device_manager/core/drivers/module_driver.dart';
import 'package:soleux_device_manager/core/transport/transport.dart';
import 'package:soleux_device_manager/data/models/channel.dart';
import 'package:soleux_device_manager/data/models/module.dart';
import 'package:soleux_device_manager/features/configuration/drivers/driver_factory.dart';

/// App environment + config.
final appConfigProvider = Provider((ref) => Env.config);

/// In-memory registry of discovered modules + their drivers. Starts empty;
/// modules are added through [ModuleRepository.addDiscoveredModule] once
/// discovery or IP-based add reaches the transport layer.
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

  ModuleRepository({required this.factory}) : super(const []);

  List<Channel> channelsOf(String moduleId) =>
      channelsByModule[moduleId] ?? const [];

  void addDiscoveredModule(
      Module module, List<Channel> channels, Transport transport) {
    channelsByModule[module.id] = channels;
    drivers[module.id] = factory.create(module, transport, channels);
    state = [...state, module];
  }
}
