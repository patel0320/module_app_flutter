import 'package:soleux_device_manager/data/models/module.dart';

import 'dimmer_driver.dart';

/// DC lighting dimming module (4 Ã— 12-24V PWM outputs).
class DcDimmerDriver extends DimmerDriver {
  DcDimmerDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.dcDimmer;
}
