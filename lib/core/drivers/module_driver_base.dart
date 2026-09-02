import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soleux_device_manager/core/transport/app_command.dart';
import 'package:soleux_device_manager/core/transport/transport.dart';
import 'package:soleux_device_manager/data/models/channel.dart';
import 'package:soleux_device_manager/data/models/channel_status.dart';
import 'package:soleux_device_manager/data/models/module.dart';

import 'module_driver.dart';

/// Shared behaviour: maps driver calls to [AppCommand] envelopes and forwards
/// them through the injected [Transport]. Also exposes a derived status stream
/// by listening to inbound messages.
abstract class BaseModuleDriver implements ModuleDriver {
  final Module module;
  final Transport transport;
  final List<Channel> channels;

  final StreamController<ChannelStatus> _status =
      StreamController<ChannelStatus>.broadcast();

  BaseModuleDriver({
    required this.module,
    required this.transport,
    required this.channels,
  }) {
    transport.inboundMessages.listen(_onInbound);
  }

  Channel _channelFor(Object? index) {
    final i = index is int ? index : (index as num?)?.toInt();
    return channels.firstWhere((c) => c.index == i,
        orElse: () =>
            channels.isNotEmpty ? channels.first : throw StateError(''));
  }

  void _onInbound(Map<String, dynamic> message) {
    Channel current;
    try {
      current = _channelFor(message['channel']);
    } catch (e, st) {
      debugPrint('BaseModuleDriver: channel lookup failed: $e\n$st');
      return;
    }
    final temp = message['temperature'];
    if (temp is num) {
      _emit(current, ChannelState.on, temperatureC: temp.toDouble());
      return;
    }
    final raw = message['value'];
    if (raw is bool) {
      _emit(current, raw ? ChannelState.on : ChannelState.off);
    } else if (raw is num) {
      _emit(current, raw == 0 ? ChannelState.off : ChannelState.dimmed,
          brightness: raw.round());
    }
  }

  void _emit(Channel channel, ChannelState state,
      {int? brightness, double? temperatureC}) {
    _status.add(ChannelStatus(
      channelId: channel.id,
      state: state,
      brightness: brightness,
      temperatureC: temperatureC,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Stream<ChannelStatus> statusStream() => _status.stream;

  @override
  Future<void> setRelay(Channel channel, bool on) async {
    await transport.send(AppCommand.relay(
      on ? ChannelState.on : ChannelState.off,
      module.id,
      channel.index,
    ));
  }

  @override
  Future<void> setBrightness(Channel channel, int pct) async {
    await transport
        .send(AppCommand.dim(module.id, channel.index, pct.clamp(0, 100)));
  }

  @override
  Future<void> blindMove(Channel channel, BlindDirection dir) async {
    await transport.send(AppCommand.blind(module.id, channel.index, dir));
  }

  @override
  Future<bool> testConnection() async {
    final result =
        await transport.send(AppCommand(action: 'ping', moduleId: module.id));
    return result.success;
  }

  @override
  Future<double> readTemperature() async =>
      throw UnimplementedError('Not a temperature module');

  @override
  Future<void> applyConfig(ModuleConfig config) async {}

  @override
  Future<void> configureInput(InputConfig input) async {}
}
