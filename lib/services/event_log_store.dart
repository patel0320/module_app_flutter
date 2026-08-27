// lib/services/event_log_store.dart
//
// App-wide, single source of truth for the 30-day event history (brief
// section 2.4). The Event History screen reads from this store and rebuilds
// via ListenableBuilder / addListener.
//
// Every module ON/OFF action, scenario run and automation trigger is recorded
// here through the helper methods below, then persisted through
// [EventLogRepository] so history survives app restarts. A 30-day retention
// policy prunes anything older than [retention].
import 'package:flutter/foundation.dart';

import '../data/event_log_repository.dart';
import '../models/models.dart';
import 'scenario_runner.dart';

class EventLogStore extends ChangeNotifier {
  EventLogStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static EventLogStore shared = EventLogStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static EventLogStore forTesting() => EventLogStore._();

  /// Retention window for the rolling history (brief section 2.4).
  static const Duration retention = Duration(days: 30);

  EventLogRepository? _repo;
  List<EventLogEntry> _entries = [];
  bool _loaded = false;

  /// The current event history, most recent first (unmodifiable view).
  List<EventLogEntry> get entries {
    final sorted = [..._entries]..sort((a, b) => b.time.compareTo(a.time));
    return List.unmodifiable(sorted);
  }

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get isEmpty => _entries.isEmpty;

  /// Tracks the most recent timestamp handed out so consecutive events always
  /// get a strictly increasing time - this keeps [entries] (which is sorted
  /// newest-first) deterministic even when several are recorded within the
  /// same clock tick.
  DateTime? _lastTime;

  DateTime _nextTime() {
    final now = DateTime.now();
    final t = (_lastTime != null && !now.isAfter(_lastTime!))
        ? _lastTime!.add(const Duration(milliseconds: 1))
        : now;
    _lastTime = t;
    return t;
  }

  /// Loads the persisted event history exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _repo = await EventLogRepository.load();
      _entries = _repo!.fetch();
    } catch (_) {
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

  /// Appends a freshly occurred event, prunes out-of-window entries, then
  /// persists everything.
  Future<void> record(EventLogEntry entry) async {
    await init();
    _entries.add(entry);
    await _prune();
    await commit();
  }

  /// Records a module output being switched ON or OFF (relay / blind).
  Future<void> recordModuleAction({
    required String moduleName,
    required String outputName,
    required bool on,
    String source = 'Manual control',
  }) =>
      record(EventLogEntry(
        time: _nextTime(),
        title: '$outputName turned ${on ? 'ON' : 'OFF'}',
        subtitle: '$moduleName · $source',
      ));

  /// Records a dimmer output being set to a brightness level.
  Future<void> recordBrightness({
    required String moduleName,
    required String outputName,
    required int pct,
    String source = 'Manual control',
  }) =>
      record(EventLogEntry(
        time: _nextTime(),
        title: '$outputName set to $pct%',
        subtitle: '$moduleName · $source',
      ));

  /// Records a tap-to-run scenario being executed.
  Future<void> recordScenario({required String scenarioName}) => record(
        EventLogEntry(
          time: _nextTime(),
          title: 'Scenario ran: $scenarioName',
          subtitle: 'Scenario',
        ),
      );

  /// Records the outcome of every action in a scenario run, so the history
  /// shows each action's detail and success/failure.
  Future<void> recordScenarioResult(ScenarioRunResult result) async {
    await init();
    for (final action in result.actions) {
      _entries.add(EventLogEntry(
        time: _nextTime(),
        title:
            '${action.success ? 'Success' : 'Failed'}: ${action.description}',
        subtitle: 'Scenario: ${result.scenarioName} · ${action.detail}',
      ));
    }
    await _prune();
    await commit();
  }

  /// Records an automation rule firing on its trigger.
  Future<void> recordAutomation({required String automationName}) => record(
        EventLogEntry(
          time: _nextTime(),
          title: 'Automation triggered: $automationName',
          subtitle: 'Automation',
        ),
      );

  /// Clears the entire event history.
  Future<void> clear() async {
    await init();
    _entries = [];
    await _repo?.clear();
    notifyListeners();
  }
}
