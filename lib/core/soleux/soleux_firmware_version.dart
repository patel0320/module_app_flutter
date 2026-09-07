// lib/core/soleux/soleux_firmware_version.dart
//
// Firmware version value type used to pick the right TCP command protocol:
//
//   - firmware >= 7.12 speaks the Soleux Control API described in
//     doc/Soleux_Control_API_Command_Specification_v0.3.md (one JSON object per
//     line on the legacy TCP port + 3);
//   - older firmware speaks the legacy TCP AT protocol described in
//     doc/PROTOCOLS.md §1 (AT+ commands on the legacy TCP port).
//
// The release gate lives here so every layer (discovery, status service,
// screens) refers to one constant instead of duplicating `7.12` string
// compares. The file is deliberately networking-free: a pure value type that
// any client can use before a connection exists.
library;

/// A parsed, orderable firmware version (`7.12`, `1.20 Build :42`, `V8.0.1`).
final class SoleuxFirmwareVersion implements Comparable<SoleuxFirmwareVersion> {
  /// Numeric dotted segments (`[7, 12]` for `7.12`).
  final List<int> parts;

  /// Optional build/tag text after the numeric prefix, e.g. ` Build :42`.
  final String? suffix;

  const SoleuxFirmwareVersion._({required this.parts, this.suffix});

  /// Parses a firmware string, extracting its leading dotted numeric prefix.
  ///
  /// Accepts an optional `v`/`V` prefix and trailing build/tag text (for
  /// example the `AT+VER` responses `VER:1.20 Build :9` or `VER:V7.12.0-b1`).
  /// Returns null when no numeric version can be found.
  static SoleuxFirmwareVersion? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    final match = RegExp(r'^[vV]?(\d+(?:\.\d+)*)').firstMatch(trimmed);
    if (match == null) return null;

    final parsed = <int>[];
    for (final segment in match.group(1)!.split('.')) {
      final value = int.tryParse(segment);
      if (value == null) return null;
      parsed.add(value);
    }

    final suffix = trimmed.substring(match.end).trim();
    return SoleuxFirmwareVersion._(
      parts: parsed,
      suffix: suffix.isEmpty ? null : suffix,
    );
  }

  /// Whether this version is at or above the Control API release gate.
  bool get supportsControlApi =>
      compareTo(SoleuxControlApiPolicy.gateVersion) >= 0;

  @override
  int compareTo(SoleuxFirmwareVersion other) {
    final length =
        parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a < b ? -1 : 1;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is SoleuxFirmwareVersion &&
      other.suffix == suffix &&
      _sameParts(other.parts);

  bool _sameParts(List<int> other) {
    if (other.length != parts.length) return false;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(parts) ^ Object.hashAll([suffix]);

  @override
  String toString() => parts.join('.') + (suffix == null ? '' : ' $suffix');
}

/// Policy for choosing the TCP command protocol from a firmware version.
///
/// doc/Soleux_Control_API_Command_Specification_v0.3.md is the transport-neutral
/// command model introduced with this release; modules below the gate keep
/// using the legacy TCP AT commands documented in doc/PROTOCOLS.md.
abstract final class SoleuxControlApiPolicy {
  SoleuxControlApiPolicy._();

  /// First firmware release that exposes the Control API command model.
  static const String minimumFirmware = '7.12';

  /// The parsed gate version, [minimumFirmware].
  static final SoleuxFirmwareVersion gateVersion =
      SoleuxFirmwareVersion.tryParse(minimumFirmware)!;

  /// True when [firmware] is known and is at or above [minimumFirmware].
  /// Unknown or unparseable versions return false so the caller can fall back
  /// to discovery advertisement / runtime probing.
  static bool supportsControlApi(String? firmware) =>
      SoleuxFirmwareVersion.tryParse(firmware)?.supportsControlApi ?? false;
}
