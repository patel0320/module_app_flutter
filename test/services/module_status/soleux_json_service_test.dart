// Integration tests for SoleuxJsonService: request/response id matching,
// buffered line routing, legacy event parsing and the legacy AT+ control
// helper, driven over real loopback sockets. The default framing is the
// Control API envelope (plain JSON lines); legacy `J:` lines are also covered.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_device_event.dart';
import 'package:soleux_device_manager/services/module_status/module_tcp_service.dart';
import 'package:soleux_device_manager/services/module_status/soleux_json_fetcher.dart';
import 'package:soleux_device_manager/services/module_status/soleux_json_service.dart';

/// A fake Soleux device: accepts one TCP connection and answers JSON
/// `hello` / `get_relay_configuration` / `set_output_state` requests (from a
/// plain Control API JSON line or a legacy `J:` line, matched by id) and
/// legacy `AT+...` commands with `OK`.
class _FakeSoleuxDevice {
  final ServerSocket server;
  final List<String> received = [];

  _FakeSoleuxDevice._(this.server);

  static Future<_FakeSoleuxDevice> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final device = _FakeSoleuxDevice._(server);
    server.listen((socket) {
      device._handle(socket);
    });
    return device;
  }

  int get port => server.port;

  void _handle(Socket socket) => _onInbound(socket);

  void _onInbound(Socket socket) {
    final buffer = StringBuffer();
    socket.listen((bytes) {
      buffer.write(utf8.decode(bytes));
      var text = buffer.toString();
      var idx = text.indexOf('\n');
      while (idx >= 0) {
        var line = text.substring(0, idx);
        while (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }
        received.add(line);
        _reply(line, socket).ignore();
        final rest = text.substring(idx + 1);
        buffer.clear();
        buffer.write(rest);
        text = rest;
        idx = text.indexOf('\n');
      }
    }, onDone: () => socket.destroy());
  }

  Future<void> _reply(String line, Socket socket) async {
    final legacy = line.startsWith('J:');
    final jsonBody =
        legacy ? line.substring(2) : (line.startsWith('{') ? line : null);
    if (jsonBody != null) {
      final request = jsonDecode(jsonBody) as Map<String, dynamic>;
      final id = request['id'];
      final action = request['action'];
      Map<String, dynamic> result;
      if (action == 'hello') {
        result = {
          'protocol': 2,
          'device': 'relay_module',
          'name': 'Plant Room Relays',
          'input_count': 8,
          'virtual_input_count': 2,
          'output_count': 8,
        };
      } else if (action == 'get_relay_configuration') {
        result = {
          'input_count': 2,
          'virtual_input_count': 1,
          'output_count': 4,
          'outputs': [
            {
              'channel': 0,
              'output_name': 'Server',
              'output_state': true,
              'output_on_delay': 0,
              'output_off_delay': 0,
              'output_on_run_time': 0,
              'output_off_run_time': 0,
              'start_delay': 0,
              'initial_state': 0,
              'turn_off_disable': false,
              'restart_disable': false,
            }
          ],
          'inputs': [
            {
              'channel': 0,
              'input_name': 'Door',
              'input_state': false,
              'input_enabled': 1,
            }
          ],
          'mapping': [],
        };
      } else if (action == 'set_output_state') {
        result = {
          'channel': request['params']['channel'],
          'requested_state': request['params']['state'],
          'actual_state': request['params']['state'],
          'pending': false,
        };
      } else if (action == 'toggle_output') {
        result = {
          'channel': request['params']['channel'],
          'actual_state': true,
          'pending': false,
        };
      } else {
        result = {};
      }
      // Send the response in two half-lines to exercise chunked framing.
      final envelope = {
        'protocol': 2,
        'id': id,
        'ok': true,
        'result': result,
      };
      final body = legacy
          ? 'J:${jsonEncode(envelope)}\r\n'
          : '${jsonEncode(envelope)}\r\n';
      socket.write(body.substring(0, body.length ~/ 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      socket.write(body.substring(body.length ~/ 2));
    } else {
      // Legacy command -> OK.
      socket.write('OK\r\n');
    }
  }
}

void main() {
  test('message parsing by SoleuxLegacyEvent', () {
    expect(
        SoleuxLegacyEvent.parse('OUT:0:ON').type, SoleuxLegacyEventType.output);
    expect(SoleuxLegacyEvent.parse('OUT:0:ON').channel, 0);
    expect(SoleuxLegacyEvent.parse('IN:1:OFF').state, isFalse);
    expect(SoleuxLegacyEvent.parse('OVERRIDE:ON').type,
        SoleuxLegacyEventType.overrideOn);
    expect(SoleuxLegacyEvent.parse('OVERRIDE:OFF').type,
        SoleuxLegacyEventType.overrideOff);
    expect(SoleuxLegacyEvent.parse('GETENERGY:229.7:1.25:274.2:E').type,
        SoleuxLegacyEventType.energy);
    expect(SoleuxLegacyEvent.parse('OK').type, SoleuxLegacyEventType.ok);
    expect(SoleuxLegacyEvent.parse('Error : Function Disabled').type,
        SoleuxLegacyEventType.error);
    expect(SoleuxLegacyEvent.parse('SYSTEMP:34').kv['SYSTEMP'], '34');
  });

  test('feed() routes J: vs legacy lines without sockets', () {
    // A service with an inert connection: we bypass `connect` and drive
    // `feed` directly (visibleForTesting).
    final connection = ModuleTcpConnection(
        host: '127.0.0.1', port: 1, timeout: const Duration(seconds: 1));
    final service = SoleuxJsonService(connection: connection);
    final jsonEvents = <Map<String, dynamic>>[];
    final legacyEvents = <SoleuxLegacyEvent>[];
    service.jsonEventStream.listen(jsonEvents.add);
    service.eventStream.listen(legacyEvents.add);

    service.feed(
        'J:{"protocol":2,"id":99,"ok":true,"result":{"device":"dimmer"}}\r\n');
    service.feed('OUT:0:ON\r\n');
    service.feed('J:{"id":100,"ok":false,"error":"oops"}\r\n');

    // The two unmatched J: lines surface as JSON events; the legacy OUT line
    // routes to the legacy event stream.
    expect(jsonEvents, hasLength(2));
    expect(jsonEvents.first['device'], 'dimmer');
    expect(legacyEvents.map((e) => e.type), [SoleuxLegacyEventType.output]);
    service.dispose();
  });

  test('feed() routes unsolicited Control API device events', () {
    // An inert connection driven with `feed` (visibleForTesting).
    final connection = ModuleTcpConnection(
        host: '127.0.0.1', port: 1, timeout: const Duration(seconds: 1));
    final service = SoleuxJsonService(connection: connection);
    final deviceEvents = <SoleuxDeviceEvent>[];
    service.deviceEventStream.listen(deviceEvents.add);

    service.feed('{"protocol":3,"event":"output_state_changed",'
        '"subscription_id":"sub-7","data":{"channel":0,"previous_state":false,'
        '"state":true,"pending":false,"source":"windows-app","revision":312,'
        '"timestamp":"2026-08-31T10:20:30+00:00"}}\r\n');
    // A device event must not be re-parsed as a legacy `OUT:` line or an
    // unmatched JSON response.
    expect(deviceEvents, hasLength(1));
    expect(deviceEvents.single.type, SoleuxDeviceEventType.outputStateChanged);
    expect(deviceEvents.single.channel, 0);
    expect(deviceEvents.single.state, isTrue);
    expect(deviceEvents.single.revision, 312);

    // Interleaved command responses and legacy lines still route normally.
    final jsonEvents = <Map<String, dynamic>>[];
    service.jsonEventStream.listen(jsonEvents.add);
    service.feed(
        '{"protocol":2,"id":99,"ok":true,"result":{"device":"dimmer"}}\r\n');
    expect(jsonEvents, hasLength(1));

    service.feed('OUT:2:OFF\r\n');
    expect(deviceEvents, hasLength(1),
        reason: 'legacy OUT lines must not become device events');

    service.dispose();
  });

  test('feed() routes protocol-2 broadcast events (id:null + result payload)',
      () {
    final connection = ModuleTcpConnection(
        host: '127.0.0.1', port: 1, timeout: const Duration(seconds: 1));
    final service = SoleuxJsonService(connection: connection);
    final deviceEvents = <SoleuxDeviceEvent>[];
    service.deviceEventStream.listen(deviceEvents.add);

    // Soleux-Mobile-TCP-Protocol.md broadcasts: id null, ok true, payload under
    // `result`. They must be routed as device events - never as a command
    // response (their `id` is null so they cannot match an in-flight request).
    service.feed('{"protocol":2,"id":null,"ok":true,'
        '"event":"input_state_changed",'
        '"result":{"channel":0,"state":true,"revision":1789531200000}}\r\n');
    service.feed('{"protocol":2,"id":null,"ok":true,'
        '"event":"output_state_changed",'
        '"result":{"channel":2,"state":false,"revision":1789531200123}}\r\n');
    service.feed('{"protocol":2,"id":null,"ok":true,"event":"system_status",'
        '"result":{"revision":1789531205000,'
        '"system":{"cpu_temp_c":47.0},'
        '"network":{"lan_ip":"192.168.1.50"}}}\r\n');

    expect(deviceEvents, hasLength(3));
    final input = deviceEvents[0];
    expect(input.type, SoleuxDeviceEventType.inputStateChanged);
    expect(input.channel, 0);
    expect(input.state, isTrue);
    expect(input.revision, 1789531200000);

    final output = deviceEvents[1];
    expect(output.type, SoleuxDeviceEventType.outputStateChanged);
    expect(output.channel, 2);
    expect(output.state, isFalse);

    final status = deviceEvents[2];
    expect(status.type, SoleuxDeviceEventType.systemStatus);
    expect(status.system!['cpu_temp_c'], 47.0);

    service.dispose();
  });

  test('request() matches responses by id over a real socket', () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(connection: connection);
    await service.connect();
    expect(service.isConnected, isTrue);

    final hello = await service.hello(timeout: const Duration(seconds: 3));
    expect(hello.ok, isTrue);
    expect(hello.id, 1);
    expect(hello.result!['device'], 'relay_module');
    expect(hello.result!['output_count'], 8);

    final config = await service.getRelayConfiguration(
        timeout: const Duration(seconds: 3));
    expect(config.ok, isTrue);
    final parsed = SoleuxRelayConfiguration.fromResult(config.result!);
    expect(parsed.outputCount, 4);
    expect(parsed.outputs.single.name, 'Server');
    expect(parsed.outputs.single.state, isTrue);

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });

  test('Control API framing: plain JSON lines carry the protocol envelope',
      () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(connection: connection);
    await service.connect();
    expect(service.framing, SoleuxJsonFraming.controlApi);

    await service.hello(timeout: const Duration(seconds: 3));
    // No J: prefix on the Control API transport; the envelope advertises the
    // protocol version.
    expect(fake.received.first, startsWith('{'));
    expect(fake.received.first, contains('"protocol":2'));
    expect(fake.received.first, contains('"action":"hello"'));
    expect(fake.received.every((line) => !line.startsWith('J:')), isTrue);

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });

  test('set_output_state and toggle_output replace the AT control commands',
      () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(connection: connection);
    await service.connect();

    final on = await service.setOutputState(3, true);
    expect(on.ok, isTrue);
    expect(on.result!['channel'], 3);
    expect(on.result!['requested_state'], isTrue);
    expect(fake.received.last, contains('"action":"set_output_state"'));

    final off = await service.setOutputState(3, false);
    expect(off.ok, isTrue);
    expect(off.result!['requested_state'], isFalse);

    final toggle = await service.toggleOutput(3);
    expect(toggle.ok, isTrue);
    expect(fake.received.last, contains('"action":"toggle_output"'));

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });

  test('legacy framings still send J: prefixed lines', () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(
        connection: connection, framing: SoleuxJsonFraming.legacyJ);
    await service.connect();

    final hello = await service.hello(timeout: const Duration(seconds: 3));
    expect(hello.ok, isTrue);
    expect(fake.received.first, startsWith('J:'));
    expect(fake.received.first, contains('"protocol":2'));

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });

  test('legacy() sends AT+ and collects the OK acknowledgement', () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(connection: connection);
    await service.connect();

    final raw = await service.legacy('AT+ON:0\r');
    expect(raw, 'OK');
    expect(fake.received, contains('AT+ON:0'));

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });

  test('non-J lines are surfaced on the legacy event stream in-session',
      () async {
    final fake = await _FakeSoleuxDevice.start();
    final connection = ModuleTcpConnection(
        host: '127.0.0.1',
        port: fake.port,
        timeout: const Duration(seconds: 2));
    final service = SoleuxJsonService(connection: connection);
    final events = <SoleuxLegacyEvent>[];
    service.eventStream.listen(events.add);
    await service.connect();

    // Hello forces the fake to write JSON; then a legacy echo command pushes
    // an `OUT:` line? Simulate an unsolicited line via a raw legacy command
    // that the fake answers with a status line before OK.
    await service.legacy('AT+OUTSTAT:0\r');
    // Any OK log proves the event stream fired at least once.
    expect(events.any((e) => e.type == SoleuxLegacyEventType.ok), isTrue);

    await service.disconnect();
    service.dispose();
    await fake.server.close();
  });
}
