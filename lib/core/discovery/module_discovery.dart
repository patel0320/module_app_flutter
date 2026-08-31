// lib/core/discovery/module_discovery.dart
//
// Implements the Soleux UDP discovery protocol described in
// doc/Soleux-Network-Discovery-and-DCP.md §1 (protocol version 2.0):
//
//  1. The app broadcasts a JSON request to UDP port 8000:
//       { "GUID": "8C93472D-2EF0-4B82-BE96-4FBBED57783F",
//         "VER": "2.0",
//         "PORT": "<client_tcp_port>" }
//  2. Each Soleux device validates the GUID, dedups the broadcast, and opens a
//     NEW TCP connection back to the app's IP on the advertised callback
//     <client_tcp_port>.
//  3. Over that TCP connection the device sends its identity response:
//       GUID:<family-guid>
//       VER:<firmware>
//       PORT:<tcp_port>
//       SN:<serial_number>
//       NAME:<app_name>
//
// The TCP peer address is authoritative for the device IP; unknown fields are
// ignored for forward compatibility.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/module_store.dart';
import '../soleux/soleux_device_family.dart';

/// Platform channel for the Android WifiManager.MulticastLock (see
/// MainActivity.kt). WiFi NICs filter out broadcast/multicast traffic unless
/// the app holds this lock, which silently kills device discovery on Android
/// phones. No-op on every other platform.
const MethodChannel _androidWifiLock =
    MethodChannel('soleux.device_manager/wifi_lock');

/// The identity fields a responding device reports during discovery.
class DiscoveredModule {
  /// Device-family GUID (doc/Soleux-Network-Discovery-and-DCP.md identity
  /// table). Distinct from the app's discovery-request GUID.
  final String guid;

  /// Installed device firmware version.
  final String version;

  /// TCP command HostPort returned by the device.
  final int tcpPort;

  /// Device serial number (identifies an individual physical device).
  final String serial;

  /// User-configured device name.
  final String name;

  /// Device IPv4 address (the TCP callback peer address).
  final String ip;

  /// Resolved [SoleuxDeviceFamily] from [guid], or null when unknown.
  final SoleuxDeviceFamily? family;

  /// UDP heartbeat port (TCP HostPort + 2) for reachability checks.
  int get heartbeatPort => SoleuxConstants.heartbeatPort(tcpPort);

  const DiscoveredModule({
    required this.guid,
    required this.version,
    required this.tcpPort,
    required this.serial,
    required this.name,
    required this.ip,
    this.family,
  });

  /// Stable identity key used for deduplication.
  ///
  /// Serial number is preferred when present and stable; otherwise the family
  /// GUID plus IP (doc: "Deduplicate by serial number, then MAC/IP").
  String get dedupeKey => serial.isNotEmpty ? 'sn:$serial' : 'ip:$guid@$ip';

  /// Parses a `KEY:value` identity response (one value per line), matched by
  /// field name rather than line order. Unknown fields are ignored for
  /// forward compatibility. Exposed for tests and alternative transports.
  static DiscoveredModule? parseIdentityResponse(String text, String ip) {
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
    // `PORT` is the canonical field; PDU V1.0 also answers legacy `Port`.
    final portRaw = map['PORT'] ?? map['Port'];
    final guid = map['GUID']!;
    return DiscoveredModule(
      guid: guid,
      version: map['VER'] ?? '',
      tcpPort:
          int.tryParse(portRaw ?? '') ?? SoleuxConstants.defaultCommandPort,
      serial: map['SN'] ?? '',
      name: map['NAME'] ?? '',
      ip: ip,
      family: SoleuxDeviceFamilies.fromGuid(guid),
    );
  }
}

/// Sends the UDP discovery broadcast and collects PDU identity responses.
///
/// Simple implementation: bound to a fresh local TCP listener, broadcasts the
/// request, then accepts the inbound identity connections until [timeout].
class ModuleDiscovery {
  /// Broadcast request target port (doc §1): UDP 8000.
  static const int discoveryPort = SoleuxConstants.discoveryPort;

  /// Client-side discovery-request identity expected by every device.
  static const String requestGuid = SoleuxConstants.discoveryGuid;

  /// Discovery protocol version carried in the broadcast request.
  static const String requestVersion = SoleuxConstants.discoveryVersion;

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
    } catch (e, st) {
      debugPrint('ModuleDiscovery: discovery pass failed: $e\n$st');
      rethrow;
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
    } catch (e, st) {
      debugPrint('ModuleDiscovery: wifi lock acquire failed: $e\n$st');
    }
  }

  static Future<void> _releaseAndroidWifiLock() async {
    if (!Platform.isAndroid) return;
    try {
      await _androidWifiLock.invokeMethod('release');
    } catch (e, st) {
      debugPrint('ModuleDiscovery: wifi lock release failed: $e\n$st');
    }
  }

  Future<void> _broadcast(int localTcpPort, Duration timeout) async {
    final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    udp.broadcastEnabled = true;
    final targets = await _broadcastTargets(timeout);
    final payload = utf8.encode(jsonEncode({
      'GUID': requestGuid,
      'VER': requestVersion,
      'PORT': localTcpPort,
    }));

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
      // Real per-interface netmasks; unknown masks fall back
      // to the /24 assumption with the global broadcast as insurance.
      final netmasks = await _maskByInterface();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          result
              .add(directedSubnetBroadcast(addr.address, netmasks[iface.name]));
        }
      }
    } catch (e, st) {
      debugPrint('ModuleDiscovery: enumerating broadcast interfaces failed '
          '(falling back to global broadcast): $e\n$st');
    }
    try {
      await ModuleStore.shared.init();
      for (final module in ModuleStore.shared.modules) {
        final ip = InternetAddress.tryParse(module.ipAddress);
        if (ip != null && ip.type == InternetAddressType.IPv4) {
          result.add(ip);
        }
      }
    } catch (e, st) {
      debugPrint('ModuleDiscovery: loading known modules for unicast '
          'requests failed: $e\n$st');
    }
    return result.toList();
  }

  /// Resolves the IPv4 subnet mask for each local interface, keyed by
  /// interface name.
  ///
  /// Android cannot read `/proc/net/route` (SELinux denies `getattr` on
  /// `proc_net` for `untrusted_app`, which surfaces as an `avc: denied`
  /// violation in logcat), so the active interface's prefix length is obtained
  /// from `ConnectivityManager` via the native platform channel
  /// (`soleux.device_manager/wifi_lock`, `ipv4LinkInfo`). On other platforms
  /// (Linux desktop) the routing table is still parsed from `/proc/net/route`;
  /// any failure falls back to the /24 assumption.
  static Future<Map<String, int>> _maskByInterface() async {
    if (Platform.isAndroid) {
      return _androidNetmasks();
    }
    return _linuxProcNetmasks();
  }

  /// Android: reads `interface` / `ip` / `prefix` for the active network from
  /// the platform channel; converts the prefix length to a big-endian /proc
  /// style 32-bit mask (e.g. /24 => `0xFFFFFF00`). Returns an empty map when
  /// the channel is unavailable or the network has no IPv4 link address.
  static Future<Map<String, int>> _androidNetmasks() async {
    try {
      final info = await _androidWifiLock
          .invokeMethod<Map<Object?, Object?>>('ipv4LinkInfo');
      if (info == null) return const {};
      final iface = info['interface'] as String?;
      final prefix = info['prefix'];
      if (iface == null || iface.isEmpty || prefix is! int) return const {};
      if (prefix <= 0 || prefix > 32) return const {};
      return {iface: _prefixToMask(prefix)};
    } catch (e, st) {
      debugPrint('ModuleDiscovery: android netmask lookup failed (using /24 '
          'fallback): $e\n$st');
      return const {};
    }
  }

  /// Converts a CIDR prefix length into a big-endian 32-bit netmask value.
  static int _prefixToMask(int prefix) {
    if (prefix <= 0) return 0;
    if (prefix >= 32) return 0xFFFFFFFF;
    return (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  }

  /// Parses `/proc/net/route` (Linux desktop only) for the real netmask of
  /// each interface (default-route entry), so directed broadcasts are
  /// computed against the actual subnet instead of assuming /24. The four
  /// hex bytes are stored little-endian (e.g. /24 => `00FFFFFF`).
  static Map<String, int> _linuxProcNetmasks() {
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
    } catch (e, st) {
      debugPrint('ModuleDiscovery: reading /proc/net/route failed (using /24 '
          'fallback): $e\n$st');
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
        final device = DiscoveredModule.parseIdentityResponse(
            buffer.toString(), socket.remoteAddress.address);
        // Deduplicate by serial number first (fallback: GUID+IP). A physical
        // device may answer on more than one interface.
        if (device != null &&
            !results.any((r) => r.dedupeKey == device.dedupeKey)) {
          debugPrint(
              'Discovered module: ${device.guid} @ ${device.ip} (${device.name})');
          results.add(device);
        }
      },
      onError: (_) {},
      onDone: () => socket.destroy(),
    );
  }
}
