import 'channel.dart';

class ChannelStatus {
  final String channelId;
  final ChannelState state;
  final int? brightness;
  final double? temperatureC;
  final DateTime updatedAt;

  const ChannelStatus({
    required this.channelId,
    required this.state,
    this.brightness,
    this.temperatureC,
    required this.updatedAt,
  });
}
