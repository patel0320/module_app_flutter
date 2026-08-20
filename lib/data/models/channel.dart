enum ChannelState { on, off, dimmed, unknown }

enum BlindDirection { up, down, stop }

class Channel {
  final String id;
  final String moduleId;
  final int index;
  final String name;
  final String? icon;
  final bool enabled;
  final ChannelState state;
  final int? brightness; // 0-100 for dimmers.

  const Channel({
    required this.id,
    required this.moduleId,
    required this.index,
    required this.name,
    this.icon,
    this.enabled = true,
    this.state = ChannelState.unknown,
    this.brightness,
  });

  Channel copyWith({String? name, String? icon, bool? enabled, ChannelState? state, int? brightness}) {
    return Channel(
      id: id,
      moduleId: moduleId,
      index: index,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      enabled: enabled ?? this.enabled,
      state: state ?? this.state,
      brightness: brightness ?? this.brightness,
    );
  }
}
