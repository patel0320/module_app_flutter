// lib/services/status_log_store.dart
//
// App-wide, single source of truth for the Notification History (brief
// section I, point 2). Every real status event is recorded here and persisted
// through [StatusLogRepository] so the history survives app restarts:
//
//   - OFFLINE   "Heartbeat or connection was lost"
//   - RESTORED  "Device is online again"
//   - FIRMWARE  "Firmware version reported: X" / "Firmware changed from A to B"
//
// The Notification History screen reads from this store and rebuilds via
// ListenableBuilder. A 30-day retention policy prunes anything older than
// [retention].
import 'package:flutter/widgets.dart';
import 'package:soleux_device_manager/l10n/gen/app_localizations.dart';

import '../data/status_log_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StatusLogStore extends ChangeNotifier {
  StatusLogStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static StatusLogStore shared = StatusLogStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static StatusLogStore forTesting() => StatusLogStore._();

  /// Retention window for the rolling notification history.
  static const Duration retention = Duration(days: 30);

  StatusLogRepository? _repo;
  List<StatusLogEntry> _entries = [];
  bool _loaded = false;

  /// The current notification history, most recent first (unmodifiable view).
  List<StatusLogEntry> get entries {
    final sorted = [..._entries]..sort((a, b) => b.time.compareTo(a.time));
    return List.unmodifiable(sorted);
  }

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get isEmpty => _entries.isEmpty;

  /// Tracks the most recent timestamp handed out so consecutive events always
  /// get a strictly increasing time.
  DateTime? _lastTime;

  DateTime _nextTime() {
    final now = DateTime.now();
    final t = (_lastTime != null && !now.isAfter(_lastTime!))
        ? _lastTime!.add(const Duration(milliseconds: 1))
        : now;
    _lastTime = t;
    return t;
  }

  /// The active [Locale] for building localized history messages.
  Locale get _locale => appLocaleNotifier.value;

  /// Localized strings for the active locale without needing a BuildContext.
  AppLocalizations get l10n => lookupAppLocalizations(_locale);

  /// Loads the persisted notification history exactly once. Safe to call
  /// repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _repo = await StatusLogRepository.load();
      _entries = _repo!.fetch();
    } catch (e, st) {
      debugPrint('StatusLogStore: loading history failed: $e\n$st');
      _entries = [];
    }
    _loaded = true;
    if (await _prune()) {
      await commit();
    } else {
      notifyListeners();
    }
  }

  /// Persists the current history and broadcasts a change.
  Future<void> commit() async {
    await _repo?.saveAll(_entries);
    notifyListeners();
  }

  /// Applies the 30-day retention policy, dropping any entry older than
  /// [retention]. Returns whether anything was removed.
  Future<bool> _prune() async {
    final cutoff = DateTime.now().subtract(retention);
    final before = _entries.length;
    _entries.removeWhere((e) => e.time.isBefore(cutoff));
    return _entries.length != before;
  }

  /// Appends a freshly occurred status event, prunes out-of-window entries,
  /// then persists everything.
  Future<void> record(StatusLogEntry entry) async {
    await init();
    _entries.add(entry);
    await _prune();
    await commit();
  }

  /// Records a module going offline.
  Future<void> recordOffline(String deviceName) => record(StatusLogEntry(
        time: _nextTime(),
        type: StatusLogType.offline,
        deviceName: deviceName,
        message: l10n.statusLogMsgOffline,
      ));

  /// Records a module coming back online.
  Future<void> recordRestored(String deviceName) => record(StatusLogEntry(
        time: _nextTime(),
        type: StatusLogType.restored,
        deviceName: deviceName,
        message: l10n.statusLogMsgRestored,
      ));

  /// Records a module reporting its firmware version for the first time
  /// (e.g. a fresh install or an OTA update landing on an unknown version).
  Future<void> recordFirmwareReported(String deviceName, String version) =>
      record(StatusLogEntry(
        time: _nextTime(),
        type: StatusLogType.firmware,
        deviceName: deviceName,
        message: l10n.statusLogMsgFirmwareReported(version),
      ));

  /// Records a module firmware version change (old -> new).
  Future<void> recordFirmwareChanged(
          String deviceName, String fromVersion, String toVersion) =>
      record(StatusLogEntry(
        time: _nextTime(),
        type: StatusLogType.firmware,
        deviceName: deviceName,
        message: l10n.statusLogMsgFirmwareChanged(fromVersion, toVersion),
      ));

  /// Clears the entire notification history.
  Future<void> clear() async {
    await init();
    _entries = [];
    await _repo?.clear();
    notifyListeners();
  }
}
