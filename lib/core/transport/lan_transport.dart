import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_command.dart';
import 'transport.dart';

/// Direct LAN TCP/IP transport (brief §2.1 "Local Control"). Opens a short-lived
/// socket per command so we control timeouts precisely for low-latency control.
class LanTransport implements Transport {
  @override
  String get name => 'lan';

  final String _host;
  final int _port;
  final Duration _timeout;
  final StreamController<Map<String, dynamic>> _inbound =
      StreamController<Map<String, dynamic>>.broadcast();

  LanTransport({
    required String host,
    required int port,
    Duration timeout = const Duration(milliseconds: 300),
  })  : _host = host,
        _port = port,
        _timeout = timeout;

  @override
  Stream<Map<String, dynamic>> get inboundMessages => _inbound.stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    if (!_inbound.isClosed) await _inbound.close();
  }

  @override
  Future<TransportResult> send(AppCommand command, {Duration? timeout}) async {
    final effectiveTimeout = timeout ?? _timeout;
    Socket? socket;
    try {
      socket = await Socket.connect(_host, _port).timeout(effectiveTimeout);
      socket.write(utf8.encode(command.encode()));

      final response = await utf8
          .decodeStream(socket)
          .timeout(effectiveTimeout)
          .catchError((Object _) => '');

      if (response.isNotEmpty) {
        try {
          final decoded = jsonDecode(response);
          if (decoded is Map<String, dynamic>) {
            _inbound.add(decoded);
          }
        } catch (_) {/* ignore malformed response */}
      }
      return const TransportResult(usedTransport: 'lan', success: true);
    } on SocketException catch (e) {
      return TransportResult(usedTransport: 'lan', success: false, error: e);
    } on TimeoutException catch (e) {
      return TransportResult(usedTransport: 'lan', success: false, error: e);
    } catch (e) {
      return TransportResult(usedTransport: 'lan', success: false, error: e);
    } finally {
      socket?.destroy();
    }
  }
}
