import 'dart:async';

import 'package:module_app_flutter/core/transport/transport.dart';
import 'package:module_app_flutter/data/models/channel.dart';
import 'package:module_app_flutter/data/models/channel_status.dart';
import 'package:module_app_flutter/data/models/input.dart';
import 'package:module_app_flutter/data/models/module.dart';

/// Configuration patch applied to a module (naming, icons, behaviour).
class ModuleConfig {
  final Map<String, Object?> values;
  const ModuleConfig(this.values);
}

/// Config patch applied to a physical input (mode + optional binding).
class InputConfig {
  final PhysicalInputMode mode;
  final String? bindKey;
  final Map<String, Object?> raw;
  const InputConfig(this.mode, this.bindKey, [this.raw = const {}]);
}

/// Abstract driver contract. Implementations route through an injected
/// [Transport] so logic is transport-agnostic and testable with [MockTransport].
abstract class ModuleDriver {
  ModuleType get type;

  Future<bool> testConnection();

  /// Real-time state updates for this module's channels.
  Stream<ChannelStatus> statusStream();

  Future<void> setRelay(Channel channel, bool on);

  /// Brightness as integer percentage 0-100 (dimmers).
  Future<void> setBrightness(Channel channel, int pct);

  /// Blind movement with toggle-stop semantics for [BlindDirection.up]/down.
  Future<void> blindMove(Channel channel, BlindDirection dir);

  /// Module internal temperature in Celsius (temperature module).
  Future<double> readTemperature();

  Future<void> applyConfig(ModuleConfig config);

  Future<void> configureInput(InputConfig input);
}
