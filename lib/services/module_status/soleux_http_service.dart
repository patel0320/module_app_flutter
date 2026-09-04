// lib/services/module_status/soleux_http_service.dart
//
// HTTP/HTTPS implementation of the transport-neutral [SoleuxControlApiService]
// surface (doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport
// mapping"): every command is dispatched to the same handler as the TCP
// service via `POST /api/v1/command`, so the request body, response envelope
// and error mapping are identical to the persistent TCP socket transport.
//
//   - HTTP  port 80  -> http://<host>/api/v1/command
//   - HTTPS port 443 -> https://<host>/api/v1/command
//
// Per the spec, when SSL is enabled the HTTP endpoint answers with a 307
// redirect that preserves the POST body; redirects are followed transparently.
// HTTP status codes map to the common envelope (spec §"HTTP status mapping"):
// 200 ok:true, 400/403/413/500 ok:false with the documented error code.
//
// TLS: the Relay Module serves HTTPS with a self-signed certificate, so the
// app accepts the peer certificate for LAN device endpoints
// (badCertificateCallback). This is a deliberate LAN trade-off: HTTPS is
// otherwise unusable against devices that ship no trusted CA certificate.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

import '../../core/logger/network_debug_logger.dart';
import '../../core/soleux/soleux_json_protocol.dart';
import 'soleux_control_api_service.dart';

/// Stateless Soleux Control API client over `POST /api/v1/command`.
///
/// No persistent connection is held: `isConnected` reflects the latest
/// reachability probe ([connect] / [ConnectionState])
class SoleuxHttpService extends SoleuxControlApiService {
  /// Endpoint every command is POSTed to.
  final Uri baseUri;

  final http.Client _client;
  final Duration _timeout;

  bool _connected = false;
  int _nextId = 1;
  final StreamController<bool> _state =
      StreamController<bool>.broadcast(sync: true);

  /// Creates a client for [baseUri] (e.g. `http://192.168.1.10/api/v1/command`
  /// or `https://192.168.1.10/api/v1/command`).
  ///
  /// [httpClient] can be injected for tests (e.g. package:http/testing
  /// MockClient); by default an IO-backed client that tolerates the LAN
  /// devices' self-signed TLS certificates over HTTPS is used.
  SoleuxHttpService({
    required this.baseUri,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 5),
  })  : _client = httpClient ?? _createIoClient(tolerateBadCertificate: baseUri.scheme == 'https'),
        _timeout = timeout;

  /// Builds an IO client; over HTTPS the peer certificate is accepted so
  /// LAN Relay Modules that ship a self-signed certificate are reachable
  /// (spec: "use https://127.0.0.1/api/v1/command when SSL is enabled").
  static http.Client _createIoClient({required bool tolerateBadCertificate}) {
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    if (tolerateBadCertificate) {
      inner.badCertificateCallback = (_, __, ___) => true;
    }
    return http_io.IOClient(inner);
  }

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get connectionStateStream => _state.stream;

  @override
  SoleuxJsonFraming get framing => SoleuxJsonFraming.controlApi;

  /// Stable endpoint key for transport replacement decisions
  /// (`http://host` / `https://host`).
  @override
  String get transportKey => baseUri.toString();

  /// Reachability probe: sends a public `hello` (§1.2 of the catalogue is
  /// `ping`, but `hello` negotiates the device identity which is what a
  /// Control API endpoint must accept first) and records the outcome.
  @override
  Future<void> connect() async {
    try {
      final response = await hello(timeout: _timeout);
      _setConnected(response.ok);
    } catch (e, st) {
      debugPrint('SoleuxHttpService: connect to $baseUri failed: $e\n$st');
      _setConnected(false);
    }
  }

  /// Marks the endpoint unreachable; the HTTP transport keeps no socket so
  /// this only resets the reachability flag.
  @override
  Future<void> disconnect() async => _setConnected(false);

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_state.isClosed) _state.add(value);
  }

  @override
  Future<SoleuxJsonResponse> request(
    String action,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final request = SoleuxJsonRequest(
      id: _nextId++,
      action: action,
      params: params,
      protocol: SoleuxProtocolVersion.defaultRequest,
    );
    final body = jsonEncode(request.toMap());
    NetworkDebugLogger.outbound('http', baseUri.toString(), body);

    final http.Response response;
    try {
      response = await _client
          .post(
            baseUri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout, onTimeout: () {
        throw TimeoutException(
            'HTTP Control API request $action (id ${request.id}) timed out');
      });
    } on http.ClientException catch (e, st) {
      debugPrint('SoleuxHttpService: POST $baseUri failed: $e\n$st');
      rethrow;
    } on SocketException catch (e, st) {
      debugPrint('SoleuxHttpService: POST $baseUri failed: $e\n$st');
      rethrow;
    } on TimeoutException catch (e, st) {
      debugPrint('SoleuxHttpService: POST $baseUri timed out: $e\n$st');
      rethrow;
    }

    NetworkDebugLogger.inbound(
        'http', baseUri.toString(), response.body);

    // 200 -> the common ok:true envelope with the command result (§"Success
    // response"). Other statuses -> the documented HTTP status mapping
    // (§"HTTP status mapping") is authoritative: 400/403/413/500 become the
    // common ok:false envelope with the corresponding stable error code.
    try {
      final parsed = SoleuxJsonResponse.parseFromBody(response.body);
      if (response.statusCode == 200) return parsed;
      return parsed.ok
          ? parsed
          : _statusError(response.statusCode, request.id);
    } on FormatException {
      return _statusError(response.statusCode, request.id);
    }
  }

  /// Synthesizes the common error envelope for a non-200 status when the
  /// device did not return one (spec §"HTTP status mapping").
  SoleuxJsonResponse _statusError(int status, int id) {
    final code = switch (status) {
      400 => 'invalid_request',
      403 => 'unauthorized',
      413 => 'payload_too_large',
      500 => 'internal_error',
      _ => 'internal_error',
    };
    return SoleuxJsonResponse(
      id: id,
      ok: false,
      error: SoleuxJsonError({
        'code': code,
        'message': 'HTTP $status from $baseUri',
      }),
    );
  }

  /// Closes the HTTP client and the connection-state stream.
  @override
  void dispose() {
    _client.close();
    if (!_state.isClosed) _state.close();
  }

  @override
  String toString() =>
      'SoleuxHttpService($baseUri, connected: $isConnected)';
}