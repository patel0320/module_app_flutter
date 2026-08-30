// lib/core/soleux/soleux_heartbeat.dart
//
// Unicast UDP heartbeat client, described in doc/Soleux-Network-Discovery-and-
// DCP.md §3. A heartbeat answers "is this known device still reachable?" - it
// is NOT a general discovery mechanism.
//
// Wire contract:
//   - the device listens on UDP `HostPort + 2` (e.g. 5007 for a 5005 unit);
//   - the app sends a JSON `ping` by unicast to the known device IP:
//       {"soleux_heartbeat":1,"op":"ping","nonce":"<64-char-max uuid>"}
//   - the device replies `pong` to the request source IP + source UDP port:
//       {"soleux_heartbeat":1,"op":"pong","nonce":"<same>",
//        "tcp_port":5005,"name":"Plant Room Relays"}
//
// The nonce is required, must not be empty, and is limited to 64 characters.
// The reference Windows client pings every 5 s and accepts replies for 1.5 s;
// mobile apps should use a less aggressive interval (battery / platform
// networking limits).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'soleux_device_family.dart';

/// A successfully matched `pong` reply.
class SoleuxPong {
  final String nonce;
  final int tcpPort;
  final String name;

  const SoleuxPong(
      {required this.nonce, required this.tcpPort, this.name = ''});

  factory SoleuxPong.parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Heartbeat pong is not an object');
    }
    final map = decoded;
    if (map['op'] != 'pong') {
      throw const FormatException('Heartbeat reply is not a pong');
    }
    return SoleuxPong(
      nonce: map['nonce'] as String? ?? '',
      tcpPort: map['tcp_port'] is num ? (map['tcp_port'] as num).toInt() : 0,
      name: map['name'] as String? ?? '',
    );
  }
}

/// Outcome of a single heartbeat ping.
class HeartbeatResult {
  final bool alive;

  /// The matched pong, when [alive].
  final SoleuxPong? pong;

  final Object? error;

  const HeartbeatResult.alive(this.pong)
      : alive = true,
        error = null;

  const HeartbeatResult.dead([this.error])
      : alive = false,
        pong = null;
}

/// Generates a nonce suitable for heartbeat and DCP correlation values.
abstract final class SoleuxNonce {
  SoleuxNonce._();

  static final Random _random = Random.secure();

  /// `<epoch-micros>-<random>` shaded to the protocol's 64-character cap.
  static String generate({int maxLength = SoleuxConstants.maxNonceLength}) {
    final base =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0xFFFFFF)}';
    if (base.length > maxLength) return base.substring(0, maxLength);
    return base;
  }
}

/// Sends one UDP heartbeat `ping` to a known device and matches the `pong`
/// reply by nonce.
class SoleuxHeartbeat {
  /// How long to keep listening for the `pong` after sending the `ping`.
  static const Duration defaultAcceptWindow = Duration(milliseconds: 1500);

  final Duration acceptWindow;

  SoleuxHeartbeat({this.acceptWindow = defaultAcceptWindow});

  /// Pings [host]'s heartbeat port (its TCP HostPort [tcpPort] + 2) using
  /// [nonce]. Returns alive when a matching `pong` arrives within
  /// [acceptWindow]; dead otherwise.
  Future<HeartbeatResult> ping(
    String host,
    int tcpPort, {
    String? nonce,
    Duration? acceptWindow,
  }) async {
    final nonceValue = nonce ?? SoleuxNonce.generate();
    if (nonceValue.isEmpty ||
        nonceValue.length > SoleuxConstants.maxNonceLength) {
      return HeartbeatResult.dead(Exception(
          'nonce must be 1..${SoleuxConstants.maxNonceLength} characters'));
    }

    final port = SoleuxConstants.heartbeatPort(tcpPort);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final window = acceptWindow ?? this.acceptWindow;
    try {
      final payload = utf8.encode(jsonEncode({
        'soleux_heartbeat': 1,
        'op': 'ping',
        'nonce': nonceValue,
      }));
      socket.send(payload, InternetAddress(host), port);

      final completer = Completer<SoleuxPong>();

      void onData(RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        // The device replies to the request source port: match the frame as a
        // pong carrying our nonce, whatever IP/UDP-port it came back on.
        try {
          final pong = SoleuxPong.parse(utf8.decode(datagram.data));
          if (pong.nonce == nonceValue && !completer.isCompleted) {
            completer.complete(pong);
          }
        } catch (_) {
          // Ignore non-pong / malformed datagrams.
        }
      }

      final subscription = socket.listen(onData);
      final timer = Timer(window, () {
        if (!completer.isCompleted) {
          completer
              .completeError(TimeoutException('heartbeat pong not received'));
        }
      });

      try {
        final pong = await completer.future;
        return HeartbeatResult.alive(pong);
      } on TimeoutException catch (e) {
        return HeartbeatResult.dead(e);
      } finally {
        timer.cancel();
        await subscription.cancel();
      }
    } catch (e) {
      debugPrint('SoleuxHeartbeat ping to $host:$port failed: $e');
      return HeartbeatResult.dead(e);
    } finally {
      socket.close();
    }
  }
}

/// Periodic heartbeat monitor for a set of known devices.
///
/// Matches the reference client cadence (every 5 s) while respecting a softer
/// mobile interval. Each tick pings the devices in parallel and reports the
/// outcome through [onResult] so the caller can flip online/offline state.
class SoleuxHeartbeatMonitor {
  final Duration interval;
  final Duration acceptWindow;
  void Function(String host, int tcpPort, HeartbeatResult result)? onResult;

  Timer? _timer;
  bool _running = false;

  SoleuxHeartbeatMonitor({
    this.interval = const Duration(seconds: 5),
    this.acceptWindow = SoleuxHeartbeat.defaultAcceptWindow,
  });

  bool get running => _running;

  /// Starts pinging [targets] every [interval]. Each target is a
  /// `(host, tcpPort)` pair. Idempotent while already running.
  void start(List<(String host, int tcpPort)> targets) {
    if (_running) {
      _timer?.cancel();
    }
    _running = true;
    _pump(targets);
    _timer = Timer.periodic(interval, (_) => _pump(targets));
  }

  Future<void> _pump(List<(String, int)> targets) async {
    if (targets.isEmpty) return;
    final client = SoleuxHeartbeat(acceptWindow: acceptWindow);
    await Future.wait([
      for (final target in targets)
        client.ping(target.$1, target.$2).then((result) {
          onResult?.call(target.$1, target.$2, result);
        }),
    ]);
  }

  /// Stops the periodic pings.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
