// lib/services/event_log_store.dart
//
// App-wide, single source of truth for the 30-day event history (brief
// section 2.4). The Event History screen reads from this store and rebuilds
// via ListenableBuilder / addListener.
//
// The in-memory list is persisted through [EventLogRepository] on every
// mutation so history survives app restarts.
import 'package:flutter/foundation.dart';

import '../data/event_log_repository.dart';
import '../models/models.dart';

class EventLogStore extends ChangeNotifier {
  EventLogStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static EventLogStore shared = EventLogStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static EventLogStore forTesting() => EventLogStore._();

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
    notifyListeners();
  }

  /// Persists the current history and broadcasts a change.
  Future<void> commit() async {
    await _repo?.saveAll(_entries);
    notifyListeners();
  }

  /// Appends a freshly occurred event and persists it to history.
  Future<void> record(EventLogEntry entry) async {
    await init();
    _entries.add(entry);
    await commit();
  }

  /// Clears the entire event history.
  Future<void> clear() async {
    await init();
    _entries = [];
    await commit();
  }
}
