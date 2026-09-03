// lib/services/module_status/control_api_command_protocol.dart
//
// [ModuleCommandProtocol] implementation over the Soleux Control API
// (doc/Soleux_Control_API_Command_Specification_v0.2.md), used for modules whose
// firmware is at or above 7.12. Commands are one JSON object per line on the
// legacy TCP port + 3 and responses are matched by `id`.
//
// Control mapping (spec "Outputs" §4 and "Dimmer control" §6):
//   - set on/off   -> set_output_state    (§4.3, replaces AT+ON/AT+OFF)
//   - toggle       -> toggle_output       (§4.4, replaces AT+TOGGLE)
//   - restart      -> restart_output      (§4.5, replaces AT+RESTART)
//   - set level    -> set_dimmer_level    (§6.3, replaces the dimmer AT command)
//   - ping         -> ping                (§1.2, replaces `AT\r`)
//
// When a catalogue action is not implemented the device returns the common
// `unsupported_command`/`unknown_action` error (spec "Common error catalogue");
// the spec says clients must not assume every catalogued action is available.
// In that case we fall back to the legacy AT command only on a pre-Control-API
// `J:` device, whose framing lives on the legacy TCP port where AT is accepted.
// The Control API port itself accepts JSON only (compatibility rule in the
// spec), so no AT fallback is ever attempted there.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/soleux/soleux_json_protocol.dart';
import 'module_command_protocol.dart';
import 'soleux_json_service.dart';

class ControlApiCommandProtocol implements ModuleCommandProtocol {
  final SoleuxJsonService _service;

  ControlApiCommandProtocol(this._service);

  @override
  ModuleCommandProtocolKind get kind => ModuleCommandProtocolKind.controlApi;

  @override
  String get name => 'control-api';

  @override
  bool get isConnected => _service.isConnected;

  /// Error codes meaning "action not implemented yet", the trigger for the
  /// legacy-AT fallback on pre-Control-API `J:` devices.
  static const Set<String> _fallbackCodes = {
    'unsupported_command',
    'unknown_action',
  };

  @override
  Future<bool> ping() async {
    try {
      return (await _service.ping()).ok;
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: ping failed: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> setOutputState(int channel, bool on) async {
    try {
      final response = await _service.setOutputState(channel, on);
      return await _maybeFallback(
          response, on ? 'AT+ON:$channel\r' : 'AT+OFF:$channel\r');
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: set_output_state($channel, $on) '
          'failed: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> toggleOutput(int channel) async {
    try {
      final response = await _service.toggleOutput(channel);
      return await _maybeFallback(response, 'AT+TOGGLE:$channel\r');
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: toggle_output($channel) failed: '
          '$e\n$st');
      return false;
    }
  }

  @override
  Future<bool> restartOutput(int channel) async {
    try {
      final response = await _service.restartOutput(channel);
      return await _maybeFallback(response, 'AT+RESTART:$channel\r');
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: restart_output($channel) failed: '
          '$e\n$st');
      return false;
    }
  }

  @override
  Future<bool> setDimmerLevel(int channel, int brightnessPct) async {
    try {
      final response = await _service.setDimmerLevel(
          channel, brightnessPct.clamp(0, 100).toDouble());
      return await _maybeFallback(
          response, 'AT+BRIGH:$channel:$brightnessPct\r');
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: set_dimmer_level($channel, '
          '$brightnessPct) failed: $e\n$st');
      return false;
    }
  }

  /// Applies a Control API response: true when accepted, otherwise falls back
  /// to the legacy AT [command] when the action is not implemented.
  Future<bool> _maybeFallback(
      SoleuxJsonResponse response, String command) async {
    if (response.ok) return true;
    final code = response.error?.code;
    if (code != null && _fallbackCodes.contains(code)) {
      return _sendLegacyAt(command);
    }
    return false;
  }

  /// Sends a legacy AT line, but only when the session is on the legacy TCP
  /// port (`legacyJ` framing). The Control API port accepts JSON only, so the
  /// fallback is a no-op there (spec compatibility rule).
  Future<bool> _sendLegacyAt(String command) async {
    if (_service.framing != SoleuxJsonFraming.legacyJ) {
      return false;
    }
    try {
      final raw = await _service.legacy(command);
      return raw.trimRight().endsWith('OK');
    } catch (e, st) {
      debugPrint('ControlApiCommandProtocol: AT fallback "$command" failed: '
          '$e\n$st');
      return false;
    }
  }
}
