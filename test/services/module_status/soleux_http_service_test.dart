// Integration tests for SoleuxHttpService over a real local HTTP server: the
// request body carries the common Control API envelope, responses are parsed
// by the common envelope, and the documented HTTP status mapping applies
// (doc/Soleux_Control_API_Command_Specification_v0.2.md §"HTTP status mapping"
// and §"Transport mapping").
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_json_protocol.dart';
import 'package:soleux_device_manager/services/module_status/soleux_http_service.dart';

/// A fake Soleux device exposing the Control API HTTP endpoint: a single
/// `POST /api/v1/command` handler that answers the implemented actions with the
/// common `ok:true` envelope. `nextStatus` / `sendEnvelope` drive the HTTP
/// status-mapping tests.
class _FakeHttpSoleuxDevice {
  final HttpServer server;
  final List<Map<String, dynamic>> received = [];
  final Map<int, bool> outputs = {};

  int nextStatus = 200;

  /// When false and [nextStatus] != 200 the body is not the common envelope,
  /// forcing the client's status mapping fallback.
  bool sendEnvelope = true;

  _FakeHttpSoleuxDevice._(this.server);

  static Future<_FakeHttpSoleuxDevice> start() async {
    final server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    final device = _FakeHttpSoleuxDevice._(server);
    server.listen(device._handle);
    return device;
  }

  int get port => server.port;

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }
    received.add({
      'path': request.uri.path,
      'contentType': request.headers.contentType.toString(),
      'body': envelope,
    });

    final id = envelope['id'];
    final action = envelope['action'] as String? ?? '';
    final params =
        envelope['params'] is Map ? envelope['params'] as Map<String, dynamic> : const <String, dynamic>{};

    if (request.uri.path != '/api/v1/command') {
      request.response.statusCode = 404;
      request.response.write(jsonEncode({
        'protocol': 2,
        'id': id,
        'ok': false,
        'error': {'code': 'unknown_action', 'message': 'not found'},
      }));
      await request.response.close();
      return;
    }

    if (nextStatus != 200) {
      request.response.statusCode = nextStatus;
      if (sendEnvelope) {
        request.response.write(jsonEncode({
          'protocol': 2,
          'id': id,
          'ok': false,
          'error': {'code': 'invalid_request', 'message': 'forced status'},
        }));
      } else {
        request.response.write('not a json envelope');
      }
      await request.response.close();
      return;
    }

    final result = _resultFor(action, params);
    request.response.statusCode = 200;
    request.response.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    request.response.write(jsonEncode({
      'protocol': 2,
      'id': id,
      'ok': true,
      'result': result,
    }));
    await request.response.close();
  }

  Map<String, dynamic> _resultFor(String action, Map<String, dynamic> params) {
    switch (action) {
      case 'hello':
        return {
          'protocol': 2,
          'device': 'relay_module',
          'name': 'Plant Room Relays',
          'input_count': 8,
          'virtual_input_count': 2,
          'output_count': 8,
        };
      case 'get_relay_configuration':
        return {
          'input_count': 1,
          'virtual_input_count': 0,
          'output_count': 2,
          'outputs': [
            for (var ch = 0; ch < 2; ch++)
              {
                'channel': ch,
                'output_name': 'Output ${ch + 1}',
                'output_state': outputs[ch] ?? false,
              }
          ],
          'inputs': const [],
          'mapping': const [],
        };
      case 'set_output_state':
        final ch = params['channel'] as int;
        final st = params['state'] as bool;
        outputs[ch] = st;
        return {
          'channel': ch,
          'requested_state': st,
          'actual_state': st,
          'pending': false,
        };
      case 'ping':
        return {'server_time': '2026-09-03T10:00:00+00:00', 'uptime_ms': 1234};
      default:
        return {};
    }
  }
}

void main() {
  test('hello / get_relay_configuration / set_output_state over HTTP', () async {
    final fake = await _FakeHttpSoleuxDevice.start();
    final service = SoleuxHttpService(
      baseUri: Uri.parse('http://127.0.0.1:${fake.port}/api/v1/command'),
      timeout: const Duration(seconds: 3),
    );

    await service.connect();
    expect(service.isConnected, isTrue);
    expect(service.framing, SoleuxJsonFraming.controlApi);
    expect(service.transportKey,
        'http://127.0.0.1:${fake.port}/api/v1/command');

    // The request body is the common Control API envelope; the endpoint and
    // media type match the spec (§"Implemented Relay Module endpoint").
    final first = fake.received.first;
    expect(first['path'], '/api/v1/command');
    expect(first['contentType'], contains('application/json'));
    expect((first['body'] as Map)['protocol'], 2);
    expect((first['body'] as Map)['action'], 'hello');

    final config = await service.getRelayConfiguration(
        timeout: const Duration(seconds: 3));
    expect(config.ok, isTrue);
    expect(config.result!['output_count'], 2);

    final on = await service.setOutputState(3, true);
    expect(on.ok, isTrue);
    expect(on.result!['channel'], 3);
    expect(on.result!['requested_state'], isTrue);
    expect(fake.received.last['body']['action'], 'set_output_state');

    final off = await service.setOutputState(3, false);
    expect(off.ok, isTrue);
    expect(off.result!['actual_state'], isFalse);

    service.dispose();
    await fake.server.close();
  });

  test('ping is dispatched as the public Control API action', () async {
    final fake = await _FakeHttpSoleuxDevice.start();
    final service = SoleuxHttpService(
      baseUri: Uri.parse('http://127.0.0.1:${fake.port}/api/v1/command'),
      timeout: const Duration(seconds: 3),
    );
    final pong = await service.ping(timeout: const Duration(seconds: 3));
    expect(pong.ok, isTrue);
    expect(pong.result!['uptime_ms'], 1234);
    expect(fake.received.last['body']['action'], 'ping');

    service.dispose();
    await fake.server.close();
  });

  test('non-200 statuses map to the common ok:false error envelope', () async {
    final fake = await _FakeHttpSoleuxDevice.start();
    final service = SoleuxHttpService(
      baseUri: Uri.parse('http://127.0.0.1:${fake.port}/api/v1/command'),
      timeout: const Duration(seconds: 3),
    );

    // Envelope present -> device error code is preserved.
    fake.nextStatus = 400;
    final rejected = await service.hello();
    expect(rejected.ok, isFalse);
    expect(rejected.error!.code, 'invalid_request');

    // 403 -> unauthorized (spec table), even when the device paired it with an
    // envelope claiming a different code.
    fake.nextStatus = 403;
    fake.sendEnvelope = true;
    final denied = await service.hello();
    expect(denied.ok, isFalse);
    expect(denied.error!.code, 'unauthorized');

    // Non-envelope 500 body -> synthesized internal_error.
    fake.nextStatus = 500;
    fake.sendEnvelope = false;
    final failed = await service.hello();
    expect(failed.ok, isFalse);
    expect(failed.error!.code, 'internal_error');

    service.dispose();
    await fake.server.close();
  });

  test('connect() records reachability from the hello probe', () async {
    final fake = await _FakeHttpSoleuxDevice.start();
    final service = SoleuxHttpService(
      baseUri: Uri.parse('http://127.0.0.1:${fake.port}/api/v1/command'),
      timeout: const Duration(seconds: 3),
    );
    expect(service.isConnected, isFalse);
    await service.connect();
    expect(service.isConnected, isTrue);
    await service.disconnect();
    expect(service.isConnected, isFalse);

    service.dispose();
    await fake.server.close();
  });

  test('endpoint is unreachable when nothing listens', () async {
    // A port that is not listening (bind, read the port, close).
    final server =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0, shared: true);
    final port = server.port;
    await server.close();

    final service = SoleuxHttpService(
      baseUri: Uri.parse('http://127.0.0.1:$port/api/v1/command'),
      timeout: const Duration(seconds: 1),
    );
    await service.connect();
    expect(service.isConnected, isFalse);
    service.dispose();
  });
}
