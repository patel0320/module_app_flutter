// lib/services/notification_service.dart
//
// Local notification layer (brief section 3.2 "Push Notifications"). Presents
// the four real-time alerts the app produces as OS-level local notifications
// on iOS / Android whenever the corresponding preference in the Settings ->
// Notifications screen is enabled:
//
//   - a module going offline or coming back online,
//   - a module temperature leaving its configured range,
//   - an output that has been left ON for too long,
//   - a smart automation firing.
//
// Every notification is gated by [SettingsStore] so the toggles in the
// notifications screen decide which alerts are actually shown. The plugin is
// initialized from the app entry point AND from the background status worker
// isolate, so alerts can surface even while the app is suspended.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'settings_store.dart';

/// Thin wrapper around `flutter_local_notifications` that maps app events to
/// localized OS notifications, honouring the notification preferences.
class LocalNotificationService {
  LocalNotificationService._();

  /// App-wide shared instance used by the launch path, screens and the
  /// background worker. Each isolate gets its own instance.
  static LocalNotificationService shared = LocalNotificationService._();

  /// Android notification channel ids, one per alert category.
  static const String channelModuleStatus = 'module_status';
  static const String channelTemperature = 'module_temperature';
  static const String channelOutputLeftOn = 'output_left_on';
  static const String channelAutomation = 'automation';

  /// How long an output must remain ON before the "left ON too long" alert
  /// fires (an output that turns OFF resets the timer). Default matches the
  /// threshold configured in Settings -> Notifications; this constant is the
  /// fallback used when no setting is provided.
  static const Duration outputLeftOnThreshold = Duration(hours: 12);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 0;

  /// True once [initialize] has completed on this platform.
  bool get initialized => _initialized;

  /// Local notifications are only meaningful on mobile.
  static bool get _nativeSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Initializes the plugin and requests notification permission. Idempotent.
  /// Safe to call from the background worker isolate as well.
  Future<void> initialize() async {
    if (_initialized || !_nativeSupported) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      for (final channel in _androidChannels) {
        await android.createNotificationChannel(channel);
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  List<AndroidNotificationChannel> get _androidChannels => const [
        AndroidNotificationChannel(
          channelModuleStatus,
          'Module status',
          description: 'Module goes offline or comes back online',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          channelTemperature,
          'Temperature',
          description: 'Module temperature out of range',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          channelOutputLeftOn,
          'Output left ON',
          description: 'An output has been left ON too long',
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          channelAutomation,
          'Automations',
          description: 'A smart automation was triggered',
          importance: Importance.defaultImportance,
        ),
      ];

  /// The active [Locale] for building localized notification strings.
  Locale get _locale => appLocaleNotifier.value;

  /// Alerts the user that [module] changed connectivity, iff the "Module
  /// offline / back online" toggle is enabled.
  Future<void> showModuleStatusChanged(DeviceModule module, bool online) async {
    if (!SettingsStore.shared.moduleStatus) return;
    await _show(
      channel: channelModuleStatus,
      title: online
          ? _l10n.notifyModuleOnline(module.name)
          : _l10n.notifyModuleOffline(module.name),
      body: module.roomName.isEmpty
          ? module.ipAddress
          : '${module.roomName} \u00b7 ${module.ipAddress}',
    );
  }

  /// Alerts the user that [module]'s internal temperature is outside the
  /// configured thresholds, iff the "Temperature threshold exceeded" toggle
  /// is enabled.
  Future<void> showTemperatureAlert(DeviceModule module) async {
    if (!SettingsStore.shared.temperature) return;
    await _show(
      channel: channelTemperature,
      title: _l10n.notifyTempExceeded(module.name),
      body: _l10n.notifyTempExceededBody(
        module.internalTempC.toStringAsFixed(1),
      ),
    );
  }

  /// Alerts the user that [output] on [module] has been left ON for longer
  /// than [duration] (default [outputLeftOnThreshold]), iff the "Output left
  /// ON too long" toggle is enabled.
  Future<void> showOutputLeftOn(
    DeviceModule module,
    ChannelOutput output, {
    Duration duration = outputLeftOnThreshold,
  }) async {
    if (!SettingsStore.shared.outputLeftOn) return;
    await _show(
      channel: channelOutputLeftOn,
      title: _l10n.notifyOutputLeftOn(output.name),
      body: _l10n.notifyOutputLeftOnBody(
        module.name,
        formatDuration(duration),
      ),
    );
  }

  /// Alerts the user that [automationName] fired, iff the "Automation
  /// triggered" toggle is enabled.
  Future<void> showAutomationTriggered(String automationName) async {
    if (!SettingsStore.shared.automationTriggered) return;
    await _show(
      channel: channelAutomation,
      title: _l10n.notifyAutomationTriggered,
      body: _l10n.notifyAutomationTriggeredBody(automationName),
    );
  }

  /// Localized strings for the active locale without needing a BuildContext.
  AppLocalizations get _l10n => lookupAppLocalizations(_locale);

  /// Formats [duration] as a short human-readable "Xh Ym" string.
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  Future<void> _show({
    required String channel,
    required String title,
    required String body,
  }) async {
    if (!_initialized || !_nativeSupported) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(channel, _channelName(channel),
          importance: Importance.high, priority: Priority.high),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(_nextId++, title, body, details);
  }

  /// Human-readable Android channel name for [channel] (used by the OS
  /// settings screen when the channel already exists under this id).
  String _channelName(String channel) {
    switch (channel) {
      case channelModuleStatus:
        return 'Module status';
      case channelTemperature:
        return 'Temperature';
      case channelOutputLeftOn:
        return 'Output left ON';
      case channelAutomation:
        return 'Automations';
    }
    return channel;
  }
}