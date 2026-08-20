import 'dart:async';
import 'dart:convert';

import 'app_command.dart';
import 'transport.dart';

/// Development transport used when no hardware is present. Records commands and
/// lets tests assert exact payloads / fallback behaviour.
class MockTransport implements Transport {
  final List<AppCommand> sent = [];
  final StreamController<Map<String, dynamic>> _inbound =
      StreamController<Map<String, dynamic>>.broadcast();
  bool succeed;
  int latencyMillis;

  MockTransport({this.succeed = true, this.latencyMillis = 0});

  @override
  String get name => 'mock';

  @override
  Stream<Map<String, dynamic>> get inboundMessages => _inbound.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  void emit(Map<String, dynamic> message) => _inbound.add(message);

  @override
  Future<TransportResult> send(AppCommand command, {Duration? timeout}) async {
    if (latencyMillis > 0) await Future<void>.delayed(Duration(milliseconds: latencyMillis));
    sent.add(command);
    if (succeed) {
      emit(jsonDecode(command.encode()) as Map<String, dynamic>);
      return const TransportResult(usedTransport: 'mock', success: true);
    }
    return const TransportResult(usedTransport: 'mock', success: false, error: 'mock failure');
  }
}
