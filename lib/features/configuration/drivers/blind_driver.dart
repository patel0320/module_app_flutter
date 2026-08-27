import 'package:soleux_device_manager/core/drivers/module_driver_base.dart';
import 'package:soleux_device_manager/core/transport/app_command.dart';
import 'package:soleux_device_manager/data/models/channel.dart';
import 'package:soleux_device_manager/data/models/module.dart';

/// DC blind motor control driver.
///
/// Implements toggle-stop behaviour (brief Â§2.3): first press of UP starts the
/// motor up, second press of UP stops it; the same applies to DOWN.
class BlindDriver extends BaseModuleDriver {
  final Map<int, BlindDirection?> _lastDirection = {};

  BlindDriver({
    required super.module,
    required super.transport,
    required super.channels,
  });

  @override
  ModuleType get type => ModuleType.blind;

  @override
  Future<void> blindMove(Channel channel, BlindDirection dir) async {
    if (dir == BlindDirection.stop) {
      _lastDirection[channel.index] = null;
      await transport.send(
          AppCommand.blind(module.id, channel.index, BlindDirection.stop));
      return;
    }

    // Toggle-stop: same direction pressed again stops the motor.
    final last = _lastDirection[channel.index];
    if (last == dir) {
      _lastDirection[channel.index] = null;
      await transport.send(
          AppCommand.blind(module.id, channel.index, BlindDirection.stop));
      return;
    }

    _lastDirection[channel.index] = dir;
    await transport.send(AppCommand.blind(module.id, channel.index, dir));
  }
}
