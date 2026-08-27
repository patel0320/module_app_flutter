import 'dart:async';

import 'app_command.dart';

/// Result of a command send attempt, reporting which transport served it so the
/// event log can record `source` = lan | mqtt (traceability per the brief).
class TransportResult {
  final String usedTransport; // 'lan' | 'mqtt' | 'mock'
  final bool success;
  final Object? error;

  const TransportResult(
      {required this.usedTransport, required this.success, this.error});
}

/// Contract for a communication transport. Drivers depend on this abstraction.
abstract class Transport {
  String get name;

  Future<TransportResult> send(AppCommand command, {Duration? timeout});

  Stream<Map<String, dynamic>> get inboundMessages;

  Future<void> connect();

  Future<void> disconnect();
}
