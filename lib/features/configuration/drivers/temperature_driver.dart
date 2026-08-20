import 'package:module_app_flutter/core/drivers/module_driver_base.dart';
import 'package:module_app_flutter/data/models/channel.dart';
import 'package:module_app_flutter/data/models/module.dart';

/// Temperature module driver: monitors the module's internal temperature.
/// Advanced thermostat logic (module's internal server) is intentionally NOT
/// exposed in v1 (LEVEL 1 scope, brief §2.3).
class TemperatureDriver extends BaseModuleDriver {
  TemperatureDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.temperature;

  @override
  Future<void> setRelay(Channel channel, bool on) async {
    throw UnsupportedError('Temperature module has no relay outputs');
  }

  @override
  Future<void> setBrightness(Channel channel, int pct) async {
    throw UnsupportedError('Temperature module has no dimmer outputs');
  }
}
