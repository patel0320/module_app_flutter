import 'package:flutter_test/flutter_test.dart';

import 'package:soleux_device_manager/core/transport/mock_transport.dart';
import 'package:soleux_device_manager/data/models/channel.dart';
import 'package:soleux_device_manager/data/models/module.dart';
import 'package:soleux_device_manager/features/configuration/drivers/blind_driver.dart';

void main() {
  const module = Module(
    id: 'm1',
    type: ModuleType.blind,
    name: 'Blind',
    ip: '192.168.1.15',
  );
  const channel =
      Channel(id: 'm1c0', moduleId: 'm1', index: 0, name: 'Bedroom blind');

  late MockTransport transport;
  late BlindDriver driver;

  setUp(() {
    transport = MockTransport();
    driver = BlindDriver(
        module: module, transport: transport, channels: const [channel]);
  });

  test('first UP press starts the motor', () async {
    await driver.blindMove(channel, BlindDirection.up);
    expect(transport.sent.single.action, 'blind_move');
    expect(transport.sent.single.value, 'up');
  });

  test('second UP press stops the motor (toggle-stop)', () async {
    await driver.blindMove(channel, BlindDirection.up);
    await driver.blindMove(channel, BlindDirection.up);
    expect(transport.sent.map((c) => c.value), ['up', 'stop']);
  });

  test('UP then DOWN moves, does not stop', () async {
    await driver.blindMove(channel, BlindDirection.up);
    await driver.blindMove(channel, BlindDirection.down);
    expect(transport.sent.map((c) => c.value), ['up', 'down']);
  });
}
