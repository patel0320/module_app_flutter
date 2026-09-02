// lib/core/soleux/soleux_heartbeat.dart
//
// Unicast UDP heartbeat client, described in
// doc/Soleux_Network_Discovery_and_Heartbeat_Specification_v0.1.md §4. A
// heartbeat answers "is this known device still reachable?" - it is NOT a
// discovery broadcast, command channel or authentication mechanism.
//
// Wire contract:
//   - the device listens on UDP `HostPort + 2` by default (e.g. 5007 for a
//     5005 unit) unless discovery advertised an explicit HEARTBEAT_PORT;
//   - the app sends a JSON `ping` by unicast to the known device IP:
//       {"soleux_heartbeat":1,"op":"ping","nonce":"<64-char-max uuid>"}
//   - the device replies `pong` to the request source IP + source UDP port:
//       {"soleux_heartbeat":1,"op":"pong","nonce":"<same>",
//        "tcp_port":5005,"name":"Plant Room Relays",
//        "api_port":5008,"api_version":3,
//        "device_id":"0000000012345678","boot_id":"4d2f9c"}
//
// The nonce is required, must not be empty, and is limited to 64 characters.
// A valid pong proves recent reachability but does not authenticate the
// device or prove a control command will succeed (spec §4.5).
//
// The 4.3 default timing profile matches the reference Windows client:
//   5 s interval, 1.5 s response window, 15 s alive threshold. Monitor clients
// should use jitter and avoid aggressive 5-second polling in the background.
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

  /// Control API TCP port when advertised (additive; normally 5008).
  final int? apiPort;

  /// Highest Control API version when advertised (additive; current 3).
  final int? apiVersion;

  /// Stable serial or MAC-derived identity when advertised (additive).
  final String? deviceId;

  /// Boot identity; changes on reboot (additive; lets clients detect a
  /// reboot per spec §4.2).
  final String? bootId;

  const SoleuxPong({
    required this.nonce,
    required this.tcpPort,
    this.name = '',
    this.apiPort,
    this.apiVersion,
    this.deviceId,
    this.bootId,
  });

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
      apiPort: map['api_port'] is num ? (map['api_port'] as num).toInt() : null,
      apiVersion: map['api_version'] is num
          ? (map['api_version'] as num).toInt()
          : null,
      deviceId: map['device_id'] as String?,
      bootId: map['boot_id'] as String?,
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
  /// How long to keep listening for the `pong` after sending the `ping`
  /// (spec §4.3 response window).
  static const Duration defaultAcceptWindow = Duration(milliseconds: 1500);

  final Duration acceptWindow;

  SoleuxHeartbeat({this.acceptWindow = defaultAcceptWindow});

  /// Pings [host]'s heartbeat port using [nonce]. The heartbeat port is the
  /// advertised [heartbeatPort] when supplied, otherwise [tcpPort] + 2.
  /// Returns alive when a matching `pong` arrives within [acceptWindow]; dead
  /// otherwise.
  ///
  /// Per spec §4.5 the reply is only accepted when its source IP matches
  /// [host] (and, in [strictSourcePort] mode, its source port equals the
  /// heartbeat port we pinged) - nonce matching alone is not sufficient on an
  /// untrusted LAN.
  Future<HeartbeatResult> ping(
    String host,
    int tcpPort, {
    int? heartbeatPort,
    String? nonce,
    Duration? acceptWindow,
    bool strictSourcePort = true,
  }) async {
    final nonceValue = nonce ?? SoleuxNonce.generate();
    if (nonceValue.isEmpty ||
        nonceValue.length > SoleuxConstants.maxNonceLength) {
      return HeartbeatResult.dead(Exception(
          'nonce must be 1..${SoleuxConstants.maxNonceLength} characters'));
    }

    final port = heartbeatPort ?? SoleuxConstants.heartbeatPort(tcpPort);
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
        // Ignore replies that did not come from the target host we pinged
        // (and, unless relaxed, the heartbeat port itself).
        if (datagram.address.address != host) return;
        if (strictSourcePort && datagram.port != port) return;
        try {
          final pong = SoleuxPong.parse(utf8.decode(datagram.data));
          if (pong.nonce == nonceValue && !completer.isCompleted) {
            completer.complete(pong);
          }
        } catch (e, st) {
          debugPrint('SoleuxHeartbeat: ignoring malformed datagram '
              'from $host:$port: $e\n$st');
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

/// Availability of a monitored heartbeat target, derived from the spec §4.4
/// state machine (minus `connected`, which is reported by an active Control
/// API session in a higher layer).
enum HeartbeatAvailability { unknown, online, suspect, offline, rebooting }

/// A single device the heartbeat monitor watches. The heartbeat port is the
/// advertised value when given, otherwise derived from the legacy TCP port.
class HeartbeatTarget {
  final String host;
  final int tcpPort;

  /// UDP heartbeat port pings are directed at.
  final int heartbeatPort;

  /// Stable per-module identity used to keep monitor state across refreshes.
  final String key;

  HeartbeatTarget({
    required this.host,
    required this.tcpPort,
    int? heartbeatPort,
    this.key = '',
  }) : heartbeatPort = heartbeatPort ?? SoleuxConstants.heartbeatPort(tcpPort);

  /// The stabilization key: [key] when provided, else `host:heartbeatPort`.
  String get stabilizationKey => key.isEmpty ? '$host:$heartbeatPort' : key;
}

/// Periodic heartbeat monitor for a set of known modules.
///
/// Matches the reference client cadence (every 5 s) while respecting a softer
/// mobile interval. Each target is scheduled on its own timer with an initial
/// random jitter so a fleet of modules does not transmit on the same boundary
/// (spec §4.5). Stateful per-target: a valid pong clears consecutive misses,
/// a missed cycle counts against the target, and the availability is
/// evaluated after every cycle against the spec §4.3 timing profile.
class SoleuxHeartbeatMonitor {
  /// Spec §4.3 default heartbeat interval.
  static const Duration defaultInterval = Duration(seconds: 5);

  /// Spec §4.3 alive threshold: a valid pong within this window keeps the
  /// module `online`.
  static const Duration defaultAliveThreshold = Duration(milliseconds: 15000);

  /// Spec §4.3 suspect threshold used as an optional enhancement.
  static const Duration defaultSuspectThreshold = Duration(milliseconds: 10000);

  /// Spec §4.4 "three full cycles missed" -> offline.
  static const int defaultMaxMissedCycles = 3;

  final Duration interval;
  final Duration acceptWindow;
  final Duration aliveThreshold;
  final Duration suspectThreshold;
  final int maxMissedCycles;

  /// Whether the first ping of each target is staggered by a random delay to
  /// desynchronize a multi-device fleet (spec §4.5).
  final bool jitter;

  /// Legacy per-ping callback, keyed by (host, tcpPort). Kept for callers
  /// that only need raw reachability.
  void Function(String host, int tcpPort, HeartbeatResult result)? onResult;

  /// Fires whenever a target's availability transitions (spec §4.4), e.g.
  /// online -> offline. Idempotent per state: duplicate pongs do not re-fire.
  void Function(HeartbeatTarget target, HeartbeatAvailability state)? onState;

  /// Fires for every *valid* pong (spec §4.2). Callers can use this to refresh
  /// `last_seen_at` without a full state transition.
  void Function(HeartbeatTarget target, SoleuxPong pong)? onPong;

  final Map<String, _TargetState> _states = {};
  bool _running = false;

  SoleuxHeartbeatMonitor({
    this.interval = defaultInterval,
    this.acceptWindow = SoleuxHeartbeat.defaultAcceptWindow,
    this.aliveThreshold = defaultAliveThreshold,
    this.suspectThreshold = defaultSuspectThreshold,
    this.maxMissedCycles = defaultMaxMissedCycles,
    this.jitter = true,
  });

  bool get running => _running;

  /// Starts pinging [targets] every [interval]. Each target is a
  /// `(host, tcpPort)` pair (heartbeat port derived as `tcpPort + 2`).
  /// Idempotent while already running (a re-start replaces the target set).
  void start(List<(String host, int tcpPort)> targets) {
    if (_running) stop();
    _running = true;
    refreshTargets([
      for (final target in targets)
        HeartbeatTarget(host: target.$1, tcpPort: target.$2),
    ]);
  }

  /// Replaces the monitored target set while preserving per-target state for
  /// targets that keep their stabilization key. Removed targets are stopped;
  /// new targets start with jitter. Safe while stopped (nothing is scheduled
  /// until [start]).
  void refreshTargets(Iterable<HeartbeatTarget> targets) {
    final incoming = <String, HeartbeatTarget>{
      for (final target in targets) target.stabilizationKey: target,
    };
    _states.removeWhere((key, state) {
      if (incoming.containsKey(key)) return false;
      state.timer?.cancel();
      return true;
    });
    for (final entry in incoming.entries) {
      final state =
          _states.putIfAbsent(entry.key, () => _TargetState(entry.value));
      state.target = entry.value;
    }
    if (_running) {
      for (final state in _states.values) {
        if (state.timer == null || !state.timer!.isActive) _schedule(state);
      }
    }
  }

  /// Last valid pong time for the target with [key], or null before any
  /// successful pong.
  DateTime? lastSeenAtFor(String key) => _states[key]?.lastSeenAt;

  /// Drops all targets and stops every pending ping. Pending state is cleared.
  void clearTargets() {
    _states.removeWhere((_, state) {
      state.timer?.cancel();
      return true;
    });
  }

  /// Stops the periodic pings. Target state is preserved for a later restart.
  void stop() {
    _running = false;
    for (final state in _states.values) {
      state.timer?.cancel();
      state.timer = null;
    }
  }

  void _schedule(_TargetState state) {
    state.timer?.cancel();
    final windowMs = interval.inMilliseconds;
    final delay = (jitter && windowMs > 0)
        ? Duration(milliseconds: state.random.nextInt(windowMs))
        : Duration.zero;
    state.timer = Timer(delay, () => _runTarget(state));
  }

  Future<void> _runTarget(_TargetState state) async {
    final client = SoleuxHeartbeat(acceptWindow: acceptWindow);
    final result = await client.ping(
      state.target.host,
      state.target.tcpPort,
      heartbeatPort: state.target.heartbeatPort,
    );

    if (result.alive && result.pong != null) {
      state.everSeen = true;
      state.missedCycles = 0;
      state.lastSeenAt = DateTime.now();
      onPong?.call(state.target, result.pong!);
    } else {
      state.missedCycles++;
    }
    onResult?.call(state.target.host, state.target.tcpPort, result);
    _reportAvail(state);

    if (_running) {
      state.timer = Timer(interval, () => _runTarget(state));
    }
  }

  void _reportAvail(_TargetState state) {
    final next = _availability(state);
    if (next == state.lastReported) return;
    state.lastReported = next;
    onState?.call(state.target, next);
  }

  /// Spec §4.4 availability from the current sample counters and last-seen
  /// age.
  HeartbeatAvailability _availability(_TargetState state) {
    final lastSeen = state.lastSeenAt;
    if (!state.everSeen || lastSeen == null) {
      return HeartbeatAvailability.unknown;
    }
    final age = DateTime.now().difference(lastSeen);
    if (age >= aliveThreshold || state.missedCycles >= maxMissedCycles) {
      return HeartbeatAvailability.offline;
    }
    if (state.missedCycles >= 2 || age > suspectThreshold) {
      return HeartbeatAvailability.suspect;
    }
    return HeartbeatAvailability.online;
  }
}

/// Per-target counters and timers held by [SoleuxHeartbeatMonitor].
class _TargetState {
  HeartbeatTarget target;
  Timer? timer;
  DateTime? lastSeenAt;
  int missedCycles = 0;
  bool everSeen = false;
  HeartbeatAvailability lastReported = HeartbeatAvailability.unknown;
  final Random random = Random();

  _TargetState(this.target);
}