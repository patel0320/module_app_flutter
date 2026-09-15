// lib/widgets/module_polling.dart
//
// Polling helper for module control screens: while a screen is open it calls
// `get_device_state` every second (via [ModuleStatusService.pollDeviceState])
// and applies the returned snapshot to the app-wide [ModuleStore], so relay /
// dimmer / blind / temperature screens always reflect the module-reported
// live state. The timer starts on [initState] and stops on [dispose]; a
// running subscription guard prevents overlapping requests when a poll takes
// longer than the 1s interval.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/module_status/module_status_service.dart';

/// One-second `get_device_state` polling for a module detail screen.
mixin ModulePollingState<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  bool _polling = false;

  /// Id of the module whose live state this screen polls.
  String get pollModuleId;

  @override
  void initState() {
    super.initState();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _pollDeviceState());
  }

  Future<void> _pollDeviceState() async {
    if (_polling) return;
    _polling = true;
    try {
      await ModuleStatusService.shared.pollDeviceState(pollModuleId);
    } finally {
      _polling = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
