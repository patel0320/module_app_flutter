// lib/services/settings_store.dart
//
// App-wide persistence for user preferences via shared_preferences:
//   - Notifications: toggles for offline / output-left-on / temperature /
//     automation-triggered alerts.
//   - Language: the active Locale (en / ro).
//   - Appearance: the active ThemeMode (light / dark / system) and the
//     Home theme palette (HomeThemeId).
//
// The theme / locale / palette values are also mirrored onto the global
// ValueNotifiers (themeModeNotifier, appLocaleNotifier, homeThemeIdNotifier)
// so MaterialApp and every screen rebuild immediately. Notification toggles
// are exposed here as a ChangeNotifier so the Notifications screen can bind
// to them instead of local widget state.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../theme/theme_palettes.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._();

  /// App-wide shared instance used by the launch path and Settings screens.
  static SettingsStore shared = SettingsStore._();

  SharedPreferences? _prefs;
  bool _loaded = false;

  // Notification preferences (ChangeNotifier-exposed so the notifications
  // screen rebuilds when they change).
  bool _moduleStatus = true;
  bool _outputLeftOn = true;
  bool _temperature = true;
  bool _automationTriggered = false;

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get moduleStatus => _moduleStatus;
  bool get outputLeftOn => _outputLeftOn;
  bool get temperature => _temperature;
  bool get automationTriggered => _automationTriggered;

  static const String _kKeyThemeMode = 'settings_theme_mode';
  static const String _kKeyLocale = 'settings_locale';
  static const String _kKeyHomeTheme = 'settings_home_theme';
  static const String _kKeyModuleStatus = 'settings_notify_module_status';
  static const String _kKeyOutputLeftOn = 'settings_notify_output_left_on';
  static const String _kKeyTemperature = 'settings_notify_temperature';
  static const String _kKeyAutomation = 'settings_notify_automation';

  /// Loads all saved preferences once and applies them to the global
  /// notifiers. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _prefs = await SharedPreferences.getInstance();

      themeModeNotifier.value =
          ThemeMode.values.asNameMap()[_prefs!.getString(_kKeyThemeMode)] ??
              themeModeNotifier.value;

      final code = _prefs!.getString(_kKeyLocale);
      if (code != null && code.isNotEmpty) {
        appLocaleNotifier.value = Locale(code);
      }

      homeThemeIdNotifier.value =
          HomeThemeId.values.asNameMap()[_prefs!.getString(_kKeyHomeTheme)] ??
              homeThemeIdNotifier.value;

      _moduleStatus = _prefs!.getBool(_kKeyModuleStatus) ?? true;
      _outputLeftOn = _prefs!.getBool(_kKeyOutputLeftOn) ?? true;
      _temperature = _prefs!.getBool(_kKeyTemperature) ?? true;
      _automationTriggered = _prefs!.getBool(_kKeyAutomation) ?? false;
    } catch (_) {
      // Keep defaults if preferences are unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  // ---- Appearance ---------------------------------------------------------

  /// Sets the active [ThemeMode] and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _prefs?.setString(_kKeyThemeMode, mode.name);
  }

  /// Sets the active [Locale] and persists it.
  Future<void> setLocale(Locale locale) async {
    appLocaleNotifier.value = locale;
    await _prefs?.setString(_kKeyLocale, locale.languageCode);
  }

  /// Sets the active Home [HomeThemeId] palette and persists it.
  Future<void> setHomeTheme(HomeThemeId id) async {
    homeThemeIdNotifier.value = id;
    await _prefs?.setString(_kKeyHomeTheme, id.name);
  }

  // ---- Notifications ------------------------------------------------------

  /// Sets whether offline / temperature alerts are enabled and persists it.
  Future<void> setModuleStatus(bool value) {
    _moduleStatus = value;
    return _persistAndNotify();
  }

  Future<void> setOutputLeftOn(bool value) {
    _outputLeftOn = value;
    return _persistAndNotify();
  }

  Future<void> setTemperature(bool value) {
    _temperature = value;
    return _persistAndNotify();
  }

  Future<void> setAutomationTriggered(bool value) {
    _automationTriggered = value;
    return _persistAndNotify();
  }

  Future<void> _persistAndNotify() async {
    await _prefs?.setBool(_kKeyModuleStatus, _moduleStatus);
    await _prefs?.setBool(_kKeyOutputLeftOn, _outputLeftOn);
    await _prefs?.setBool(_kKeyTemperature, _temperature);
    await _prefs?.setBool(_kKeyAutomation, _automationTriggered);
    notifyListeners();
  }
}
