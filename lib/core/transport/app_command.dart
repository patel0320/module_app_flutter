import 'dart:convert';

import 'package:module_app_flutter/data/models/channel.dart';

/// Command envelope shared by LAN TCP and MQTT paths (see setup.md §5.3).
class AppCommand {
  final String action;
  final String moduleId;
  final int? channel;
  final Object? value;
  final String requestId;

  const AppCommand({
    required this.action,
    required this.moduleId,
    this.channel,
    this.value,
    String? requestId,
  }) : requestId = requestId ?? 'rid';

  Map<String, Object?> toJson() => {
        'cmd': action,
        'moduleId': moduleId,
        'channel': channel,
        'value': value,
        'requestId': requestId,
      };

  String encode() => jsonEncode(toJson());

  static const actionRelayOn = 'relay_on';
  static const actionRelayOff = 'relay_off';
  static const actionDim = 'dim';
  static const actionBlindMove = 'blind_move';

  factory AppCommand.relay(ChannelState channelState, String moduleId, int channel) {
    return AppCommand(
      action: channelState == ChannelState.on ? actionRelayOn : actionRelayOff,
      moduleId: moduleId,
      channel: channel,
      value: channelState == ChannelState.on,
    );
  }

  factory AppCommand.dim(String moduleId, int channel, int brightness) {
    return AppCommand(
      action: actionDim,
      moduleId: moduleId,
      channel: channel,
      value: brightness.clamp(0, 100),
    );
  }

  factory AppCommand.blind(String moduleId, int channel, BlindDirection dir) {
    return AppCommand(
      action: actionBlindMove,
      moduleId: moduleId,
      channel: channel,
      value: dir.name,
    );
  }
}
