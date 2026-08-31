// lib/core/soleux/soleux_json_protocol.dart
//
// Codec for the Soleux TCP JSON protocol (`J:` lines), described in
// doc/Soleux-Mobile-TCP-Protocol.md §"JSON protocol".
//
// Wire contract:
//   - request and response are each one CRLF-terminated line prefixed `J:`;
//   - a request carries a unique `id`; the device echoes it in the response,
//     so clients match responses by `id`, never by arrival order;
//   - a successful response has `"ok":true` and a `result` object;
//   - a failed response has `"ok":false` and an `error` value/object;
//   - the outer `protocol` field is OPTIONAL (PDU V1.0 may omit it);
//   - unknown response properties must be ignored (forward compatibility).
//
// This file is deliberately networking-free: a pure codec that any transport
// (persistent socket, tests, mock) can use. Only JSON line framing lives here.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The prefix every JSON protocol line starts with on the wire.
const String kSoleuxJsonPrefix = 'J:';

/// JSON actions common to all supported families
/// (doc/Soleux-Mobile-TCP-Protocol.md, "Common JSON actions").
abstract final class SoleuxJsonActions {
  SoleuxJsonActions._();

  static const String hello = 'hello';
  static const String getRelayConfiguration = 'get_relay_configuration';
  static const String getPageConfiguration = 'get_page_configuration';
  static const String setPageConfiguration = 'set_page_configuration';
  static const String mutatePageRow = 'mutate_page_row';
  static const String executePageAction = 'execute_page_action';

  // Relay Module / PDU (current generation).
  static const String setInputConfiguration = 'set_input_configuration';
  static const String setOutputConfiguration = 'set_output_configuration';
  static const String setMapping = 'set_mapping';
  static const String writeHardware = 'write_hardware';
  static const String settingsBackupDownloadBegin =
      'settings_backup_download_begin';
  static const String transferUploadBegin = 'transfer_upload_begin';
  static const String transferUploadChunk = 'transfer_upload_chunk';
  static const String transferUploadFinish = 'transfer_upload_finish';
  static const String transferDownloadChunk = 'transfer_download_chunk';
  static const String transferDownloadFinish = 'transfer_download_finish';
  static const String transferCommit = 'transfer_commit';

  // AC/DC Dimmer.
  static const String setDimmerFrequency = 'set_dimmer_frequency';

  // PDU Energy Meter.
  static const String getEnergyHistory = 'get_energy_history';

  /// Row operations for [SoleuxJsonActions.mutatePageRow].
  static const String opAdd = 'add';
  static const String opUpdate = 'update';
  static const String opDelete = 'delete';
}

/// Common config pages (doc/Soleux-Mobile-TCP-Protocol.md, JSON section).
abstract final class SoleuxJsonPages {
  SoleuxJsonPages._();

  static const String automation = 'automation';
  static const String schedule = 'schedule';
  static const String settings = 'settings';
  static const String security = 'security';
  static const String system = 'system';
}

/// Energy-history parameters (PDU Energy Meter).
enum SoleuxEnergyParameter {
  voltage,
  current,
  power,
  powerFactor,
  apparentPower,
  energy
}

extension SoleuxEnergyParameterX on SoleuxEnergyParameter {
  /// The device-side parameter index (`0=voltage ... 5=energy`).
  int get index => switch (this) {
        SoleuxEnergyParameter.voltage => 0,
        SoleuxEnergyParameter.current => 1,
        SoleuxEnergyParameter.power => 2,
        SoleuxEnergyParameter.powerFactor => 3,
        SoleuxEnergyParameter.apparentPower => 4,
        SoleuxEnergyParameter.energy => 5,
      };

  /// Display unit reported by the device (V, A, W, '', VA, kWh).
  String get unit => switch (this) {
        SoleuxEnergyParameter.voltage => 'V',
        SoleuxEnergyParameter.current => 'A',
        SoleuxEnergyParameter.power => 'W',
        SoleuxEnergyParameter.powerFactor => '',
        SoleuxEnergyParameter.apparentPower => 'VA',
        SoleuxEnergyParameter.energy => 'kWh',
      };
}

/// A single outbound JSON protocol request.
class SoleuxJsonRequest {
  final int id;
  final String action;
  final Map<String, dynamic> params;

  const SoleuxJsonRequest(
      {required this.id, required this.action, this.params = const {}});

  /// Encodes the request as a single `J:` line terminated with CRLF.
  String encode() {
    final body = <String, dynamic>{
      'id': id,
      'action': action,
      'params': params,
    };
    return '$kSoleuxJsonPrefix${jsonEncode(body)}\r\n';
  }
}

/// The `error` value carried by a failed JSON response.
class SoleuxJsonError {
  final Object? raw;

  const SoleuxJsonError(this.raw);

  /// Error `code` when the device sent an object like
  /// `{"code":"internal_error","message":"..."}`.
  String? get code => raw is Map ? (raw as Map)['code'] as String? : null;

  /// Error `message` when present (string or nested in an object).
  String? get message {
    if (raw is String) return raw as String;
    if (raw is Map) return (raw as Map)['message'] as String?;
    return null;
  }

  String get summary => message ?? code ?? '$raw';
}

/// A decoded `J:` response line.
class SoleuxJsonResponse {
  /// The `id` echoed from the request this response answers.
  final int id;

  /// `true` when the request was accepted (`"ok":true`).
  final bool ok;

  /// The outer `protocol` field, when the firmware sent one (PDU V1.0 omits
  /// it, so this is nullable).
  final int? protocol;

  /// The decoded `result` map of a successful response, or null.
  final Map<String, dynamic>? result;

  /// The `error` value of a failed response, or null.
  final SoleuxJsonError? error;

  const SoleuxJsonResponse({
    required this.id,
    required this.ok,
    this.protocol,
    this.result,
    this.error,
  });

  /// Parses a raw `J:` line (without the prefix) into a response. Throws a
  /// [FormatException] when the line is not a valid JSON protocol response.
  factory SoleuxJsonResponse.parseFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Soleux JSON response is not an object');
    }
    final map = decoded;
    final id = map['id'];
    if (id is! num) {
      throw const FormatException(
          'Soleux JSON response is missing a numeric id');
    }
    final ok = map['ok'];
    if (ok is! bool) {
      throw const FormatException('Soleux JSON response is missing a bool ok');
    }

    dynamic result;
    try {
      result = map['result'];
    } catch (e, st) {
      debugPrint('SoleuxJsonResponse: reading result field failed: $e\n$st');
      result = null;
    }

    return SoleuxJsonResponse(
      id: id.toInt(),
      ok: ok,
      protocol:
          map['protocol'] is num ? (map['protocol'] as num).toInt() : null,
      result: result is Map ? Map<String, dynamic>.from(result) : null,
      error: map['error'] == null ? null : SoleuxJsonError(map['error']),
    );
  }

  /// Parses a raw wire line (already trimmed of CR/LF). Returns the response
  /// when the line is a JSON protocol line, or null when it is something else
  /// (a legacy `AT+...` event, an `OUT:`/`IN:` status, `OK`, ...). Tolerates
  /// malformed `J:` lines by returning null so one bad frame never kills the
  /// reader.
  static SoleuxJsonResponse? maybeParse(String line) {
    if (line.length < 2 || line[0] != 'J' || line[1] != ':') return null;
    try {
      return SoleuxJsonResponse.parseFromBody(line.substring(2));
    } on FormatException {
      return null;
    }
  }
}

/// Splits a raw byte/chunk stream into complete, CR/LF-delimited lines.
///
/// The firmware buffers and may flush any number of messages in a single TCP
/// segment (and may split one line across chunks), so framing must be
/// buffered rather than assuming one read == one message.
class SoleuxLineSplitter {
  final StringBuffer _buffer = StringBuffer();

  /// Feeds [chunk] and returns every complete line found (without the
  /// line terminator). A trailing partial line is kept in the buffer.
  List<String> add(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final lines = <String>[];
    var searchFrom = 0;
    while (true) {
      final lf = text.indexOf('\n', searchFrom);
      if (lf < 0) break;
      var end = lf;
      // `\r\n` -> drop the carriage return as part of the terminator.
      if (end > 0 && text[end - 1] == '\r') end -= 1;
      lines.add(text.substring(searchFrom, end));
      searchFrom = lf + 1;
    }
    if (searchFrom > 0) {
      _buffer.clear();
      if (searchFrom < text.length) {
        _buffer.write(text.substring(searchFrom));
      }
    }
    return lines;
  }

  /// Any partial line currently buffered awaiting its terminator.
  bool get hasPending => _buffer.isNotEmpty;
}
