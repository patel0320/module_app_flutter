// lib/services/module_status/module_keep_alive.dart
//
// Dart bridge to the Android foreground-service keep-alive (see
// android/.../ModuleKeepAliveService.kt).
//
// On Android the persistent module sockets and the UDP heartbeat monitor live
// in this (Dart) isolate, so they are only alive while the OS keeps the
// process running. The native foreground service does the work the isolates
// cannot: it runs as a specialUse foreground service (so the process is not
// recycled), holds a PARTIAL_WAKE_LOCK (so the CPU - and the socket event
// loop - keeps running with the screen off) and returns START_STICKY (so the
// service is restarted if the system kills it). This class simply starts /
// stops that service and reflects its state into Dart.
//
// iOS is handled separately (BGAppRefreshTask / push), so everything here is
// a no-op outside Android.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';
import 'package:soleux_device_manager/theme/app_theme.dart';

import '../module_store.dart';

class ModuleKeepAlive {
  ModuleKeepAlive._();

  static ModuleKeepAlive? _shared;
  static ModuleKeepAlive get shared => _shared ??= ModuleKeepAlive._();

  static const MethodChannel _channel =
      MethodChannel('soleux.device_manager/keep_alive');

  /// True while the Android foreground service reports running. Exposed as a
  /// [ValueListenable] so the lifecycle scheduler (and the Settings card) can
  /// react to state changes without polling the platform channel.
  final ValueNotifier<bool> running = ValueNotifier<bool>(false);

  /// The keep-alive foreground service only exists on Android.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  bool _listeningToStore = false;

  /// Starts (or refreshes) the foreground service and keeps its notification
  /// in sync with the module fleet. Sets [running] immediately so the
  /// lifecycle scheduler keeps the sockets alive even if the app backgrounds
  /// right at launch, before the platform channel round-trip completes.
  Future<void> start() async {
    if (!supported) return;
    running.value = true;
    try {
      await ModuleStore.shared.init();
      await _pushNotification();
      _listenToStore();
    } catch (e, st) {
      running.value = false;
      debugPrint('ModuleKeepAlive: start failed: $e\n$st');
    }
  }

  /// Stops the foreground service, releasing the wake lock and the persistent
  /// notification (the lifecycle scheduler resumes suspending sockets on
  /// background afterwards).
  Future<void> stop() async {
    if (!supported) return;
    running.value = false;
    _unlistenStore();
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e, st) {
      debugPrint('ModuleKeepAlive: stop failed: $e\n$st');
    }
  }

  /// True while the native foreground service is actually running. Used to
  /// reconcile [running] after an external stop (e.g. force-stopped app).
  Future<bool> isRunning() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isRunning') ?? false;
    } catch (e, st) {
      debugPrint('ModuleKeepAlive: isRunning failed: $e\n$st');
      return false;
    }
  }

  /// Whether the app is already exempt from battery optimization (Doze / App
  /// Standby), per `PowerManager.isIgnoringBatteryOptimizations()`.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!supported) return false;
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (e, st) {
      debugPrint('ModuleKeepAlive: isIgnoringBatteryOptimizations failed: '
          '$e\n$st');
      return false;
    }
  }

  /// Opens the system "allow unrestricted battery use" dialog
  /// (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). Opt-in only: never call
  /// this automatically, only from the Settings card the user explicitly opens.
  Future<void> requestBatteryOptimizationExemption() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (e, st) {
      debugPrint('ModuleKeepAlive: requestIgnoreBatteryOptimizations failed: '
          '$e\n$st');
    }
  }

  /// Re-pushes the localized notification with the current fleet size when the
  /// module set changes, so the persistent notification never shows a stale
  /// module count.
  void _listenToStore() {
    if (_listeningToStore || !supported) return;
    _listeningToStore = true;
    ModuleStore.shared.addListener(_refreshNotification);
  }

  void _unlistenStore() {
    if (!_listeningToStore) return;
    _listeningToStore = false;
    ModuleStore.shared.removeListener(_refreshNotification);
  }

  Future<void> _refreshNotification() async {
    if (!running.value) return;
    try {
      await _pushNotification();
    } catch (e, st) {
      debugPrint('ModuleKeepAlive: notification refresh failed: $e\n$st');
    }
  }

  Future<void> _pushNotification() async {
    final count = ModuleStore.shared.modules.length;
    final l10n = lookupAppLocalizations(appLocaleNotifier.value);
    await _channel.invokeMethod<void>('start', <String, Object>{
      'moduleCount': count,
      'title': l10n.keepAliveTitle,
      'text': count > 0 ? l10n.keepAliveBodyCount(count) : l10n.keepAliveBody,
    });
  }
}
