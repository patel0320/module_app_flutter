import 'package:flutter_test/flutter_test.dart';

import 'package:soleux_device_manager/core/transport/app_command.dart';
import 'package:soleux_device_manager/core/transport/failover_transport.dart';
import 'package:soleux_device_manager/core/transport/mock_transport.dart';

void main() {
  const ping = AppCommand(action: 'ping', moduleId: 'm1');

  group('FailoverTransport', () {
    test('uses LAN first while LAN succeeds', () async {
      final lan = MockTransport();
      final mqtt = MockTransport();
      final failover = FailoverTransport(lan: lan, mqtt: mqtt);

      await failover.send(ping);
      await failover.send(ping);

      expect(lan.sent, hasLength(2));
      expect(mqtt.sent, isEmpty);
    });

    test('falls back to MQTT when LAN fails', () async {
      final lan = MockTransport(succeed: false);
      final mqtt = MockTransport();
      final failover = FailoverTransport(lan: lan, mqtt: mqtt);

      final result = await failover.send(ping);

      expect(result.success, isTrue);
      expect(mqtt.sent, hasLength(1)); // served by MQTT
    });

    test('recovers to LAN after threshold consecutive LAN successes', () async {
      final lan = MockTransport(succeed: false);
      final mqtt = MockTransport();
      final failover = FailoverTransport(
        lan: lan,
        mqtt: mqtt,
        lanReconnectThreshold: 2,
      );

      await failover.send(ping); // LAN fails once -> MQTT path
      expect(mqtt.sent, hasLength(1));

      lan.succeed = true; // LAN recovers
      final lanBefore = lan.sent.length;
      await failover.send(ping); // probe 1 (recover streak 1)
      await failover.send(ping); // probe 2 (recover streak 2 -> prefer LAN)
      await failover.send(ping); // sent via LAN

      expect(lan.sent.length, greaterThan(lanBefore));
      expect(mqtt.sent, hasLength(1)); // MQTT no longer used
    });
  });
}
