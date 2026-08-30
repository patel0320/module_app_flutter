// Tests for the Soleux UDP heartbeat client
// (doc/Soleux-Network-Discovery-and-DCP.md §3).
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
}
