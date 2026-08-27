import 'package:soleux_device_manager/core/drivers/module_driver_base.dart';
import 'package:soleux_device_manager/data/models/module.dart';

/// Base class for lighting dimming drivers (DC PWM and AC phase-cut). The
/// generic brightness control lives in [BaseModuleDriver.setBrightness].
abstract class DimmerDriver extends BaseModuleDriver {
  DimmerDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type;
}
