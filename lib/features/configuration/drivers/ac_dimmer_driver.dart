import 'package:module_app_flutter/data/models/module.dart';

import 'dimmer_driver.dart';

/// AC lighting dimming module (4 × 220V outputs, phase-cut).
class AcDimmerDriver extends DimmerDriver {
  AcDimmerDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.acDimmer;
}
