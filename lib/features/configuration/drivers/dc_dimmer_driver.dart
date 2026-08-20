import 'package:module_app_flutter/data/models/module.dart';

import 'dimmer_driver.dart';

/// DC lighting dimming module (4 × 12-24V PWM outputs).
class DcDimmerDriver extends DimmerDriver {
  DcDimmerDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.dcDimmer;
}
