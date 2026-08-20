import 'dart:async';

import 'package:async/async.dart';

import 'app_command.dart';
import 'transport.dart';

/// Implements LAN-first, MQTT-fallback policy (setup.md §5.5).
class FailoverTransport implements Transport {
  final Transport lan;
  final Transport mqtt;
  final Duration lanTimeout;

  int _lanSuccessStreak = 0;

  /// Number of consecutive LAN successes required before favouring LAN again.
  final int lanReconnectThreshold;

  bool _preferLan = true;

  FailoverTransport({
    required this.lan,
    required this.mqtt,
    this.lanTimeout = const Duration(milliseconds: 300),
    this.lanReconnectThreshold = 3,
  });

  @override
  String get name => 'failover';

  @override
  Stream<Map<String, dynamic>> get inboundMessages =>
      StreamGroup.merge([lan.inboundMessages, mqtt.inboundMessages]);

  @override
  Future<void> connect() async {
    await Future.wait([lan.connect(), mqtt.connect()]);
  }

  @override
  Future<void> disconnect() async {
    await Future.wait([lan.disconnect(), mqtt.disconnect()]);
  }

  @override
  Future<TransportResult> send(AppCommand command, {Duration? timeout}) async {
    if (_preferLan) {
      final result = await lan.send(command, timeout: lanTimeout);
      if (result.success) {
        _lanSuccessStreak++;
        if (_lanSuccessStreak >= lanReconnectThreshold) _preferLan = true;
        return result;
      }
      // LAN failed -> use MQTT for this and until LAN recovers.
      _preferLan = false;
      _lanSuccessStreak = 0;
      return mqtt.send(command);
    }

    // Currently on MQTT; periodically probe LAN to recover.
    final lanProbe = await lan.send(command, timeout: lanTimeout);
    if (lanProbe.success) {
      _lanSuccessStreak++;
      if (_lanSuccessStreak >= lanReconnectThreshold) {
        _preferLan = true;
      }
      return lanProbe;
    }
    _lanSuccessStreak = 0;
    return mqtt.send(command);
  }
}
