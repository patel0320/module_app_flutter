// lib/services/module_status/module_tcp_service.dart
//
// Persistent, auto-reconnecting TCP socket client for one module. Mirrors the
// connection layer from the reference `tcp_service.dart` (TcpConnection):
//
//   - one socket is reused for the module's whole lifetime (no connect /
//     fetch / close per refresh),
//   - the socket silently reconnects (up to a bounded number of attempts) when
//     the peer drops it,
//   - every decoded chunk is published on [dataStream];
//   - connection up/down transitions are published on [connectionStateStream].
//
// Transport is deliberately module-agnostic: command/status framing lives in
// ModuleCommandService (mirror of `at_command_service.dart`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ModuleTcpConnection {
  final String host;
  final int port;
  final Duration _timeout;
  final Duration _reconnectDelay;
  static const int _maxReconnectAttempts = 10;

  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _connecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;

  final StreamController<String> _dataController =
      StreamController<String>.broadcast();
  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();

  /// Raw decoded chunks (utf8) pushed by the module.
  Stream<String> get dataStream => _dataController.stream;

  /// `true` while the socket is live, `false` when it has dropped (reconnect
  /// will be attempted automatically unless [disconnect] was called).
  Stream<bool> get connectionStateStream => _stateController.stream;

  bool get isConnected => _isConnected;
  String get key => '$host:$port';

  ModuleTcpConnection({
    required this.host,
    required this.port,
    Duration timeout = const Duration(seconds: 10),
    Duration reconnectDelay = const Duration(seconds: 3),
  })  : _timeout = timeout,
        _reconnectDelay = reconnectDelay;

  /// Ensures a live socket exists for the module.
  ///
  /// If a socket is already open it is reused as-is; otherwise a new one is
  /// created. A created socket is left connected and is never proactively
  /// torn down: it is only closed when the peer drops it (then auto-reconnect
  /// kicks in) or when [disconnect]/[dispose] is called. Safe to call
  /// repeatedly (e.g. from every status refresh) without churn.
  Future<void> connect() async {
    if (_isConnected) {
      return; // socket already alive -> reuse
    }
    if (_connecting) {
      return; // a connect is already in flight
    }
    _shouldReconnect = true;
    _connecting = true;
    try {
      final socket = await Socket.connect(host, port, timeout: _timeout);
      if (!_shouldReconnect) {
        socket.destroy();
        return;
      }
      _socket = socket;
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.encoding = utf8;

      _isConnected = true;
      _reconnectAttempts = 0;
      _stateController.add(true);

      _subscription?.cancel();
      _subscription = socket.listen(
        (bytes) {
          _reconnectAttempts = 0;
          _dataController.add(utf8.decode(bytes));
        },
        onError: (Object e) {
          debugPrint('ModuleTCP $key socket error: $e');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('ModuleTCP $key socket closed by peer');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('ModuleTCP $key connect failed: $e');
      _isConnected = false;
      _stateController.add(false);
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// Reacts to the socket being dropped. The dead socket is cleaned up and,
  /// unless auto-reconnect was disabled, a reconnect is scheduled.
  void _handleDisconnect() {
    if (_isConnected || _socket != null) {
      _isConnected = false;
      _stateController.add(false);
      _cleanup();
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('ModuleTCP $key max reconnect attempts reached');
      return;
    }
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, connect);
  }

  /// Sends raw [data] on the wire. No-ops while disconnected.
  void write(String data) {
    final socket = _socket;
    if (socket != null && _isConnected) {
      socket.write(data);
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    try {
      socket?.destroy();
    } catch (e, st) {
      debugPrint('ModuleTCP $key: socket destroy failed: $e\n$st');
    }
  }

  /// Stops auto-reconnect and closes the socket.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _stateController.add(false);
    _cleanup();
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _stateController.close();
  }
}
