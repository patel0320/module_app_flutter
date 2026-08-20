import 'package:flutter/foundation.dart';

/// Minimal structured logger. Replace the printer with a crash-reporting sink
/// (e.g. Crashlytics) in Stage 7.
class AppLogger {
  AppLogger._();

  static void log(String message, {String? tag}) {
    debugPrint('[${tag ?? 'app'}] $message');
  }

  static void error(Object error, [StackTrace? stack]) {
    debugPrint('[error] $error');
    if (stack != null) debugPrint('$stack');
  }

  static void event(String type, Map<String, Object?> payload) {
    debugPrint('[event:$type] $payload');
  }
}
