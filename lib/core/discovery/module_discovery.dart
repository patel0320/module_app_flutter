// lib/core/discovery/module_discovery.dart
//
// Implements the UDP Discovery Protocol described in doc/PROTOCOLS.md §2:
//
//  1. The app broadcasts a JSON request to UDP port 8000:
//       { "GUID": "8481fba0-f387-11ea-adc1-0242ac120002",
//         "Port": "<client_tcp_port>" }
//  2. Each PDU validates the GUID and opens a NEW TCP connection back to the
//     app's IP on the advertised <client_tcp_port>.
//  3. Over that TCP connection the PDU sends its identity response:
//       GUID:<guid>
//       VER:<version>
//       PORT:<tcp_port>
//       SN:<serial_number>
//       NAME:<app_name>
//
// This replaces the previous hardcoded simulation (`mockDiscoveredModules`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/module_store.dart';

/// Platform channel for the Android WifiManager.MulticastLock (see
/// MainActivity.kt). WiFi NICs filter out broadcast/multicast traffic unless
/// the app holds this lock, which silently kills device discovery on Android
/// phones. No-op on every other platform.
const MethodChannel _androidWifiLock =
    MethodChannel('soleux.device_manager/wifi_lock');

/// The identity fields a responding PDU reports during discovery.
class DiscoveredModule {
  final String guid;
  final String version;
  final int tcpPort;
  final String serial;
  final String name;
  final String ip;

  const DiscoveredModule({
    required this.guid,
    required this.version,
    required this.tcpPort,
    required this.serial,
    required this.name,
    required this.ip,
  });
}

/// Sends the UDP discovery broadcast and collects PDU identity responses.
///
/// Simple implementation: bound to a fresh local TCP listener, broadcasts the
/// request, then accepts the inbound identity connections until [timeout].
class ModuleDiscovery {
  /// Broadcast request target port (PROTOCOLS.md §2).
  static const int discoveryPort = 8000;

  /// Client-side request identifier expected by every PDU (PROTOCOLS.md §2).
  static const String requestGuid = '8481fba0-f387-11ea-adc1-0242ac120002';

  /// Legacy global broadcast address; sent alongside per-subnet broadcasts.
  static const _globalBroadcast = '255.255.255.255';

  /// How long to keep listening for identity responses after broadcasting.
  static const Duration defaultTimeout = Duration(seconds: 4);

  /// Number of times each broadcast target is pinged.
  static const int _broadcastRepetitions = 3;

  /// Broadcasts the discovery request and returns every PDU that answers.
  Future<List<DiscoveredModule>> discover({
    Duration timeout = defaultTimeout,
  }) async {
    final results = <DiscoveredModule>[];
    if (timeout.inMilliseconds <= 0) return results;

    // Sometimes required on the PDU side too (some firmwares also answer the
    // discovery broadcast with a broadcast/multicast); always harmless.
    await _acquireAndroidWifiLock();
    try {
      // Advertise a fresh TCP listener; PDUs dial back into this port.
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);

      server.listen((socket) {
        _readIdentity(socket, results);
      }, onError: (_) {});

      final localPort = server.port;
      // Broadcast and keep the listener accepting identity responses for the
      // full timeout window (_broadcast awaits the timeout), then close.
      await _broadcast(localPort, timeout);
      await server.close();
    } finally {
      await _releaseAndroidWifiLock();
    }
    return results;
  }

  /// On Android, WiFi frame filtering drops broadcast/multicast packets unless
  /// the process holds a WifiManager.MulticastLock. Best-effort: failures are
  /// swallowed so discovery still proceeds without it.
  static Future<void> _acquireAndroidWifiLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidWifiLock.invokeMethod('acquire');
    } catch (_) {}
  }

  static Future<void> _releaseAndroidWifiLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidWifiLock.invokeMethod('release');
    } catch (_) {}
  }

  Future<void> _broadcast(int localTcpPort, Duration timeout) async {
    final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    udp.broadcastEnabled = true;
    final targets = await _broadcastTargets(timeout);
    final payload =
        utf8.encode(jsonEncode({'GUID': requestGuid, 'Port': localTcpPort}));

    for (final target in targets) {
      for (var i = 0; i < _broadcastRepetitions; i++) {
        udp.send(payload, target, discoveryPort);
      }
    }

    await Future<void>.delayed(timeout);
    udp.close();
  }

  /// Directs broadcasts at the global address plus a directed broadcast for
  /// every IPv4 interface, so we reach PDUs on the active LAN. Also unicasts
  /// the discovery request to every already-known module IP: some access
  /// points filter broadcasts (client isolation / VLANs) while direct unicast
  /// to a known LAN address still gets through.
  Future<List<InternetAddress>> _broadcastTargets(Duration timeout) async {
    final result = <InternetAddress>{
      InternetAddress(_globalBroadcast),
    };
    try {
      final interfaces = await NetworkInterface.list().timeout(timeout);
      // Real per-interface netmasks (Linux/Android); unknown masks fall back
      // to the /24 assumption with the global broadcast as insurance.
      final netmasks = _readLinuxNetmasks();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          result
              .add(directedSubnetBroadcast(addr.address, netmasks[iface.name]));
        }
      }
    } catch (_) {
      // Fall back to the global broadcast if interfaces are unavailable.
    }
    try {
      await ModuleStore.shared.init();
      for (final module in ModuleStore.shared.modules) {
        final ip = InternetAddress.tryParse(module.ipAddress);
        if (ip != null && ip.type == InternetAddressType.IPv4) {
          result.add(ip);
        }
      }
    } catch (_) {
      // Module store may be unavailable (e.g. tests); broadcast only.
    }
    return result.toList();
  }

  /// Parses `/proc/net/route` (present on Android/Linux) for the real netmask
  /// of each interface (default-route entry), so directed broadcasts are
  /// computed against the actual subnet instead of assuming /24. The four
  /// hex bytes are stored little-endian (e.g. /24 => `00FFFFFF`).
  static Map<String, int> _readLinuxNetmasks() {
    final result = <String, int>{};
    try {
      final file = File('/proc/net/route');
      if (!file.existsSync()) return result;
      for (final line in file.readAsLinesSync().skip(1)) {
        final fields = line.trim().split(RegExp(r'\s+'));
        // Interface, Destination, Gateway, Flags, RefCnt, Use, Metric, Mask.
        if (fields.length < 9 || fields[1] != '00000000') continue;
        final rawMask = int.tryParse(fields[7], radix: 16);
        if (rawMask == null || rawMask == 0) continue;
        // Byte-swap the little-endian hex value into a big-endian IPv4 mask.
        result[fields[0]] = ((rawMask & 0xFF) << 24) |
            ((rawMask & 0xFF00) << 8) |
            ((rawMask >> 8) & 0xFF00) |
            ((rawMask >> 24) & 0xFF);
      }
    } catch (_) {
      // Non-Linux platform or unreadable procfs; caller keeps /24 fallback.
    }
    return result;
  }

  /// Computes the directed IPv4 broadcast for [host] given [prefixMask] (as a
  /// big-endian /proc-style 32-bit mask) or the classic /24 subnet when the
  /// mask is null. Exposed for tests; exported as a /24 helper on null.
  static InternetAddress directedSubnetBroadcast(String host,
      [int? prefixMask]) {
    final octets = host.split('.').map(int.tryParse).toList();
    final parts = octets.length == 4
        ? [for (final o in octets) o ?? 0]
        : const [0, 0, 0, 0];
    final ip = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
    final mask = prefixMask ?? 0xFFFFFF00;
    final broadcast = (ip & mask) | (~mask & 0xFFFFFFFF);
    return InternetAddress(
        '${(broadcast >> 24) & 0xFF}.${(broadcast >> 16) & 0xFF}.'
        '${(broadcast >> 8) & 0xFF}.${broadcast & 0xFF}');
  }

  void _readIdentity(Socket socket, List<DiscoveredModule> results) {
    final buffer = StringBuffer();
    socket.listen(
      (chunk) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final device =
            _parseIdentity(buffer.toString(), socket.remoteAddress.address);
        if (device != null && !results.any((r) => r.guid == device.guid)) {
          debugPrint(
              'Discovered module: ${device.guid} @ ${device.ip} (${device.name})');
          results.add(device);
        }
      },
      onError: (_) {},
      onDone: () => socket.destroy(),
    );
  }

  /// Parses a `KEY:value` identity response (one value per line).
  DiscoveredModule? _parseIdentity(String text, String ip) {
    if (text.isEmpty) return null;
    final map = <String, String>{};
    for (final line in text.split(RegExp(r'[\r\n]'))) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim().toUpperCase();
      final value = line.substring(idx + 1).trim();
      if (value.isNotEmpty) map[key] = value;
    }
    if (map['GUID'] == null) return null;
    return DiscoveredModule(
      guid: map['GUID']!,
      version: map['VER'] ?? '',
      tcpPort: int.tryParse(map['PORT'] ?? '') ?? 5005,
      serial: map['SN'] ?? '',
      name: map['NAME'] ?? '',
      ip: ip,
    );
  }
}
