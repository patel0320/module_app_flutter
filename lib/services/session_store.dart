// lib/services/session_store.dart
//
// App-wide sign-in session persistence (brief section 3.1). Authentication is
// simulated, but once the user signs in we persist that fact so Android / iOS
// relaunches after a process kill restore straight into the app instead of
// bouncing back through the splash + mandatory sign-in flow.
//
// This is what makes background-restore seamless: the OS can (and will) kill
// the app process while it sits in the background for a long time; WorkManager
// already covers the module-status polling, and the persisted session here
// makes the next launch land on the main shell again.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._();

  /// App-wide shared instance used by the launch path and auth screens.
  static SessionStore shared = SessionStore._();

  SharedPreferences? _prefs;
  bool _loaded = false;
  bool _signedIn = false;

  static const String _kKeySignedIn = 'session_signed_in';

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  /// Whether the user has a persisted sign-in session.
  bool get signedIn => _signedIn;

  /// Loads the persisted session exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _signedIn = _prefs!.getBool(_kKeySignedIn) ?? false;
    } catch (e, st) {
      debugPrint('SessionStore: loading session failed: $e\n$st');
      // Keep defaults if preferences are unavailable.
    }
    _loaded = true;
    notifyListeners();
  }

  /// Records a sign-in / sign-out and persists it.
  Future<void> setSignedIn(bool value) async {
    _signedIn = value;
    await _prefs?.setBool(_kKeySignedIn, value);
    notifyListeners();
  }
}
