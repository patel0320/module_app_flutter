import 'package:module_app_flutter/core/drivers/module_driver_base.dart';
import 'package:module_app_flutter/data/models/module.dart';

/// Standard relay module driver (on/off control of one or more outputs).
class RelayDriver extends BaseModuleDriver {
  RelayDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.relay;
}
