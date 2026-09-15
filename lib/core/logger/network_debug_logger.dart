import 'package:flutter/foundation.dart';

/// Logs every network payload and response in debug builds only.
///
/// All outbound wire data goes through [outbound] and every inbound reply
/// through [inbound] so a debug session shows the exact bytes exchanged on
/// each transport (TCP, MQTT, UDP heartbeat, discovery). [kDebugMode] is a
/// compile-time constant, so in release/profile builds [enabled] is false and
/// these calls are no-ops - no payload is ever emitted from production builds.
class NetworkDebugLogger {
  NetworkDebugLogger._();

  static bool _enabled = kDebugMode;

  /// Whether wire-level logging is active. Follows the build mode by default.
  static bool get enabled => _enabled;

  /// Forces logging on/off at runtime (e.g. from a settings toggle). Calling
  /// [setEnabled] with `true` in a release build has no effect because the
  /// messages are stripped at compile time.
  static void setEnabled(bool value) => _enabled = value;

  /// Logs an outbound request payload over [transport] to [endpoint].
  static void outbound(String transport, Object? endpoint, String payload) {
    if (!_enabled) return;
    debugPrint('[net:>> $transport ${endpoint ?? ''}] $payload');
  }

  /// Logs an inbound response payload received over [transport] from
  /// [endpoint].
  static void inbound(String transport, Object? endpoint, String payload) {
    if (!_enabled) return;
    debugPrint('[net:<< $transport ${endpoint ?? ''}] $payload');
  }
}
