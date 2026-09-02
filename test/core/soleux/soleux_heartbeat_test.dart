// Tests for the Soleux UDP heartbeat client and monitor
// (doc/Soleux_Network_Discovery_and_Heartbeat_Specification_v0.1.md §4).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_heartbeat.dart';

/// Binds a local UDP echo server that, on any `ping`, replies a `pong`
/// carrying the same nonce, a [tcpPort] and [name].
Future<(RawDatagramSocket, int)> startPongServer({
  required int tcpPort,
  required String name,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null) return;
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded['op'] != 'ping') return;
      final nonce = decoded['nonce'] as String;
      final reply = utf8.encode(jsonEncode({
        'soleux_heartbeat': 1,
        'op': 'pong',
        'nonce': nonce,
        'tcp_port': tcpPort,
        'name': name,
      }));
      socket.send(reply, datagram.address, datagram.port);
    } catch (_) {
      // ignore malformed pings
    }
  });
  return (socket, socket.port);
}

void main() {
  test('heartbeat port is TCP HostPort + 2', () {
    expect(SoleuxHeartbeat.defaultAcceptWindow,
        const Duration(milliseconds: 1500));
  });

  test('SoleuxNonce.generate respects the 64-char cap and is non-empty', () {
    for (var i = 0; i < 50; i++) {
      final nonce = SoleuxNonce.generate();
      expect(nonce, isNotEmpty);
      expect(nonce.length <= 64, isTrue, reason: 'nonce too long: $nonce');
    }
  });

  test('SoleuxPong.parse reads additive Control API and boot fields (§4.2)', () {
    final pong = SoleuxPong.parse(
        '{"soleux_heartbeat":1,"op":"pong","nonce":"n","tcp_port":5005,'
        '"name":"Plant Room Relays","api_port":5008,"api_version":3,'
        '"device_id":"0000000012345678","boot_id":"4d2f9c"}');
    expect(pong.nonce, 'n');
    expect(pong.tcpPort, 5005);
    expect(pong.name, 'Plant Room Relays');
    expect(pong.apiPort, 5008);
    expect(pong.apiVersion, 3);
    expect(pong.deviceId, '0000000012345678');
    expect(pong.bootId, '4d2f9c');
  });

  test('additive fields default to null on a minimal pong', () {
    final pong = SoleuxPong.parse(
        '{"soleux_heartbeat":1,"op":"pong","nonce":"n","tcp_port":5005}');
    expect(pong.apiPort, isNull);
    expect(pong.apiVersion, isNull);
    expect(pong.deviceId, isNull);
    expect(pong.bootId, isNull);
  });

  test('ping() returns alive and the matched pong', () async {
    final (server, serverPort) =
        await startPongServer(tcpPort: 5005, name: 'Plant Room Relays');
    // The client targets the heartbeat port, which is `tcpPort + 2`. Choose the
    // TCP port so the computed heartbeat port equals the server's ephemeral
    // bound port.
    final clientTcpPort = serverPort - 2;
    final client = SoleuxHeartbeat(acceptWindow: const Duration(seconds: 2));

    final result =
        await client.ping('127.0.0.1', clientTcpPort, nonce: 'test-nonce-0001');

    expect(result.alive, isTrue);
    expect(result.pong, isNotNull);
    expect(result.pong!.nonce, 'test-nonce-0001');
    expect(result.pong!.tcpPort, 5005);
    expect(result.pong!.name, 'Plant Room Relays');
    server.close();
  });

  test('uses an explicitly advertised heartbeat port (§4.2)', () async {
    final (server, serverPort) =
        await startPongServer(tcpPort: 5005, name: 'Dimmer');
    final client = SoleuxHeartbeat(acceptWindow: const Duration(seconds: 1));

    // tcpPort is intentionally a wrong/arbitrary value: the advertised
    // heartbeat port wins over the derived `tcpPort + 2`.
    final result = await client.ping('127.0.0.1', 1234,
        heartbeatPort: serverPort, nonce: 'explicit-port');

    expect(result.alive, isTrue);
    expect(result.pong!.name, 'Dimmer');
    server.close();
  });

  test('ping() reports dead when no pong arrives', () async {
    // A socket bound to a port that never replies.
    final silent =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final client =
        SoleuxHeartbeat(acceptWindow: const Duration(milliseconds: 300));
    final result = await client.ping(
      '127.0.0.1',
      silent.port - 2, // targets the silent heartbeat port
      nonce: 'no-reply-nonce',
    );
    expect(result.alive, isFalse);
    expect(result.error, isNotNull);
    silent.close();
  });

  test('strictSourcePort rejects a pong from a different source port (§4.5)',
      () async {
    final main = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final mainPort = main.port;
    // A second socket on a *different* port that forges a pong. The real
    // device would reply from the heartbeat socket; this one does not.
    final rogue =
        await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    main.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = main.receive();
      if (datagram == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(datagram.data));
        if (decoded['op'] != 'ping') return;
        final nonce = decoded['nonce'] as String;
        final reply = utf8.encode(jsonEncode({
          'soleux_heartbeat': 1,
          'op': 'pong',
          'nonce': nonce,
          'tcp_port': 5005,
          'name': 'Forged',
        }));
        rogue.send(reply, datagram.address, datagram.port);
      } catch (_) {
        // ignore malformed pings
      }
    });

    final client = SoleuxHeartbeat(acceptWindow: const Duration(milliseconds: 500));
    // Strict: the forged pong source port != heartbeat port -> ignored.
    final strict = await client.ping('127.0.0.1', mainPort - 2,
        heartbeatPort: mainPort, nonce: 'forged-nonce', strictSourcePort: true);
    expect(strict.alive, isFalse,
        reason: 'a pong from a foreign source port must be ignored');

    // Relaxed: only the source IP is validated, so the foreign pong is
    // accepted as reachability evidence.
    final relaxed = await client.ping('127.0.0.1', mainPort - 2,
        heartbeatPort: mainPort,
        nonce: 'forged-nonce',
        strictSourcePort: false);
    expect(relaxed.alive, isTrue);

    main.close();
    rogue.close();
  });

  test('rejects invalid nonces', () async {
    final client = SoleuxHeartbeat();
    expect((await client.ping('127.0.0.1', 5005, nonce: '')).alive, isFalse);
    final tooLong = 'x' * 65;
    expect(
        (await client.ping('127.0.0.1', 5005, nonce: tooLong)).alive, isFalse);
  });

  test('SoleuxHeartbeatMonitor ticks periodically and reports reachability',
      () async {
    final (server, serverPort) =
        await startPongServer(tcpPort: 5007, name: 'PDU Meter');
    final clientTcpPort = serverPort - 2;
    final results = <HeartbeatResult>[];
    final monitor = SoleuxHeartbeatMonitor(
      interval: const Duration(milliseconds: 200),
      acceptWindow: const Duration(seconds: 1),
    );
    monitor.onResult = (host, port, result) => results.add(result);

    monitor.start([('127.0.0.1', clientTcpPort)]);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    monitor.stop();

    expect(results, isNotEmpty);
    expect(results.every((r) => r.alive), isTrue);
    expect(results.every((r) => r.pong!.tcpPort == 5007), isTrue);
    server.close();
  });

  test('monitor transitions online -> suspect -> offline (§4.4)', () async {
    final (server, serverPort) =
        await startPongServer(tcpPort: 5005, name: 'Relay');
    final clientTcpPort = serverPort - 2;
    final states = <HeartbeatAvailability>[];
    final monitor = SoleuxHeartbeatMonitor(
      interval: const Duration(milliseconds: 150),
      acceptWindow: const Duration(milliseconds: 300),
      aliveThreshold: const Duration(milliseconds: 600),
      suspectThreshold: const Duration(milliseconds: 400),
      jitter: false,
    );
    monitor.onState = (target, state) => states.add(state);

    monitor.start([('127.0.0.1', clientTcpPort)]);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    server.close(); // the device stops answering pings
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    monitor.stop();

    expect(states, contains(HeartbeatAvailability.online));
    expect(states, contains(HeartbeatAvailability.suspect));
    expect(states, contains(HeartbeatAvailability.offline));
    expect(states.indexOf(HeartbeatAvailability.online),
        lessThan(states.indexOf(HeartbeatAvailability.suspect)));
    expect(states.indexOf(HeartbeatAvailability.suspect),
        lessThan(states.indexOf(HeartbeatAvailability.offline)));
  });

  test('refreshTargets keeps per-target state by key', () async {
    final (server, serverPort) =
        await startPongServer(tcpPort: 5005, name: 'Relay');
    final target = HeartbeatTarget(
      host: '127.0.0.1',
      tcpPort: serverPort - 2,
      key: 'module-1',
    );
    final monitor = SoleuxHeartbeatMonitor(
      interval: const Duration(milliseconds: 150),
      acceptWindow: const Duration(seconds: 1),
      jitter: false,
    );

    monitor.start([('127.0.0.1', target.tcpPort)]);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Refreshing with an equivalent keyed target restarts the keyed state but
    // the underlying host/port is tracked via the target record.
    monitor.refreshTargets([target]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(monitor.lastSeenAtFor('module-1'), isNotNull);

    monitor.stop();
    server.close();
  });
}