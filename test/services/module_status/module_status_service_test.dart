// End-to-end tests for ModuleStatusService: a successful ON/OFF control
// command must reflect in the store (and therefore on the relay screen) even
// when the device does not push an unsolicited `OUT:` broadcast line.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/module_store.dart';
import 'package:soleux_device_manager/services/module_status/module_status_service.dart';

/// Fake Control API device: answers `hello` / `get_relay_configuration`, and
/// acknowledges `set_output_state` with a plain `ok:true` JSON response but
/// never broadcasts an `OUT:` line (the exact scenario that used to leave the
/// relay screen stale).
class _FakeDevice {
  final ServerSocket server;
  final List<String> received = [];
  final Map<int, bool> outputs = {};

  _FakeDevice._(this.server);

  static Future<_FakeDevice> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final device = _FakeDevice._(server);
    server.listen((socket) => device._handle(socket));
    return device;
  }

  int get port => server.port;

  void _handle(Socket socket) {
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
        _reply(line, socket);
        final rest = text.substring(idx + 1);
        buffer.clear();
        buffer.write(rest);
        text = rest;
        idx = text.indexOf('\n');
      }
    }, onDone: () => socket.destroy());
  }

  void _reply(String line, Socket socket) {
    if (!line.startsWith('{')) return;
    final request = jsonDecode(line) as Map<String, dynamic>;
    final id = request['id'];
    final action = request['action'];
    Map<String, dynamic> result;
    if (action == 'hello') {
      result = {
        'protocol': 2,
        'device': 'relay_module',
        'name': 'Plant Room Relays',
        'input_count': 2,
        'virtual_input_count': 0,
        'output_count': 2,
      };
    } else if (action == 'get_relay_configuration') {
      result = {
        'input_count': 2,
        'virtual_input_count': 0,
        'output_count': 2,
        'outputs': [
          for (var ch = 0; ch < 2; ch++)
            {
              'channel': ch,
              'output_name': 'Output ${ch + 1}',
              'output_state': outputs[ch] ?? false,
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
        'inputs': const [],
        'mapping': const [],
      };
    } else if (action == 'set_output_state') {
      final ch = request['params']['channel'] as int;
      final st = request['params']['state'] as bool;
      outputs[ch] = st;
      result = {
        'channel': ch,
        'requested_state': st,
        'actual_state': st,
        'pending': false,
        'revision': 1,
      };
    } else {
      result = {};
    }
    final envelope = {
      'protocol': 2,
      'id': id,
      'ok': true,
      'result': result,
    };
    socket.write('${jsonEncode(envelope)}\r\n');
  }
}

/// Lets the debounced store commit (`_scheduleCommit`) run its course.
Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 300));

void main() {
  test('successful ON/OFF command reflects in the store without a broadcast',
      () async {
    final fake = await _FakeDevice.start();
    final store = ModuleStore.forTesting();
    // controlApiPort defaults to tcpPort + 3 -> point it at the fake server.
    final module = DeviceModule(
      id: 'm1',
      name: 'Relays',
      type: ModuleType.relay,
      ipAddress: '127.0.0.1',
      status: ConnectionStatus.offline,
      roomName: 'Room',
      internalTempC: 30,
      tcpPort: fake.port - 3,
    );
    await store.replaceAll([module]);

    final service = ModuleStatusService(store: store);
    final refreshed = await service.refreshOne(module);
    expect(refreshed, isTrue,
        reason: 'Control API probe + configuration fetch must succeed');
    await _flush();
    expect(store.byId('m1')!.channels, hasLength(2));
    expect(store.byId('m1')!.channels[0].isOn, isFalse);

    // No OUT: line is ever sent by the fake; only then does the store reflect.
    expect(await service.turnOnOutput('m1', 0), isTrue);
    await _flush();
    expect(store.byId('m1')!.channels[0].isOn, isTrue,
        reason: 'relay screen must reflect a successful ON command');

    expect(await service.turnOffOutput('m1', 0), isTrue);
    await _flush();
    expect(store.byId('m1')!.channels[0].isOn, isFalse,
        reason: 'relay screen must reflect a successful OFF command');

    // Unrelated channels are untouched.
    expect(store.byId('m1')!.channels[1].isOn, isFalse);

    service.dispose();
    await fake.server.close();
  });
}