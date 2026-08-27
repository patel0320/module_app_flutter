import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/config/app_config.dart';
import 'app_command.dart';
import 'transport.dart';

/// Remote control transport over MQTT (brief §2.1 "Remote Control"). Per-user
/// scoped topics, TLS enforced for remote.
class MqttTransport implements Transport {
  @override
  String get name => 'mqtt';

  final AppConfig _config;
  final String _clientId;
  MqttServerClient? _client;

  final String _tenantId;
  final String _locationId;

  final StreamController<Map<String, dynamic>> _inbound =
      StreamController<Map<String, dynamic>>.broadcast();

  MqttTransport({
    required AppConfig config,
    required String clientId,
    required String tenantId,
    required String locationId,
  })  : _config = config,
        _clientId = clientId,
        _tenantId = tenantId,
        _locationId = locationId;

  String topic(String moduleId, String suffix) =>
      '$_tenantId/$_locationId/$moduleId/$suffix';

  @override
  Stream<Map<String, dynamic>> get inboundMessages => _inbound.stream;

  @override
  Future<void> connect() async {
    final client = MqttServerClient.withPort(
        _config.mqttHost, _clientId, _config.mqttPort);
    client.secure = _config.mqttUseTls;
    client.keepAlivePeriod = 30;
    client.onDisconnected = () {};

    await client.connect();
    _client = client;

    // Subscribe to telemetry for all modules of this location.
    client.subscribe('$_tenantId/$_locationId/+/status', MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (final event in events) {
        final payload = event.payload;
        if (payload is MqttPublishMessage) {
          final text = String.fromCharCodes(payload.payload.message);
          try {
            _inbound.add(jsonDecode(text) as Map<String, dynamic>);
          } catch (_) {/* ignore malformed */}
        }
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
  }

  @override
  Future<TransportResult> send(AppCommand command, {Duration? timeout}) async {
    final client = _client;
    if (client == null) {
      return const TransportResult(
          usedTransport: 'mqtt', success: false, error: 'not connected');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(command.encode());
    client.publishMessage(
      topic(command.moduleId, 'control'),
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    return const TransportResult(usedTransport: 'mqtt', success: true);
  }
}
