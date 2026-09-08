// lib/data/status_log_repository.dart
//
// Local persistence layer for the Notification History (brief section I,
// point 2). Status events are stored as a JSON list under a single
// shared_preferences key so offline/restored/firmware history survives app
// restarts. Unlike the Event Log (which seeds demo data on first run), the
// notification history starts empty and only ever records real triggers.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class StatusLogRepository {
  static const String _storageKey = 'status_log';

  final SharedPreferences _prefs;

  StatusLogRepository(this._prefs);

  /// Loads the repository from the platform preferences.
  static Future<StatusLogRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StatusLogRepository(prefs);
  }

  /// Fetches the persisted notification history in stored (chronological)
  /// order.
  List<StatusLogEntry> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        StatusLogEntry.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the notification history.
  Future<void> saveAll(List<StatusLogEntry> entries) {
    final encoded = jsonEncode([for (final e in entries) e.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Clears the persisted notification history.
  Future<void> clear() => saveAll(const []);
}
