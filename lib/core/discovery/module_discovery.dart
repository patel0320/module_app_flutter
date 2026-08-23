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
    return results;
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

  /// Directs broadcasts at the global address plus a directed /24 broadcast for
  /// every IPv4 interface, so we reach PDUs on the active LAN.
  Future<List<InternetAddress>> _broadcastTargets(Duration timeout) async {
    final result = <InternetAddress>{
      InternetAddress(_globalBroadcast),
    };
    try {
      final interfaces = await NetworkInterface.list().timeout(timeout);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type != InternetAddressType.IPv4) continue;
          result.add(directedSubnetBroadcast(addr.address));
        }
      }
    } catch (_) {
      // Fall back to the global broadcast if interfaces are unavailable.
    }
    return result.toList();
  }

  /// Computes a /24 directed broadcast for [host] (typical office/marine LAN).
  /// Exposed for tests; assumes the common class-C layout.
  static InternetAddress directedSubnetBroadcast(String host) {
    final octets = host.split('.').map(int.tryParse).toList();
    final parts = octets.length == 4
        ? [for (final o in octets) o ?? 0]
        : const [0, 0, 0, 0];
    return InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
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
