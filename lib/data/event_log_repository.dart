// lib/data/event_log_repository.dart
//
// Local persistence layer for the 30-day rolling event history (brief
// section 2.4), mirroring lib/data/room_repository.dart and
// lib/data/scenario_repository.dart. Entries are stored as a JSON list under
// a single shared_preferences key so ON/OFF history survives app restarts.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'mock_data.dart';

class EventLogRepository {
  static const String _storageKey = 'event_log';
  static const String _seedKey = 'event_log_seeded';

  final SharedPreferences _prefs;

  EventLogRepository(this._prefs);

  /// Loads the store, seeding demo history entries on the very first run.
  static Future<EventLogRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = EventLogRepository(prefs);
    await repo._seedIfEmpty();
    return repo;
  }

  Future<void> _seedIfEmpty() async {
    if (_prefs.getBool(_seedKey) ?? false) return;
    await saveAll(mockEventLog());
    await _prefs.setBool(_seedKey, true);
  }

  /// Fetches the persisted event history in stored (chronological) order.
  List<EventLogEntry> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        EventLogEntry.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the event history.
  Future<void> saveAll(List<EventLogEntry> entries) {
    final encoded = jsonEncode([for (final e in entries) e.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Clears the persisted event history.
  Future<void> clear() => saveAll(const []);
}
