// lib/data/scenario_repository.dart
//
// Local persistence layer for the scenario list, mirroring
// lib/data/module_repository.dart and lib/data/room_repository.dart.
// Scenarios (with their tap-to-run actions / manual slider settings) are
// stored as a JSON list under a single shared_preferences key so edits made
// in the Scenarios editor and Home quick-access survive app restarts.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'mock_data.dart';

class ScenarioRepository {
  static const String _storageKey = 'scenarios';
  static const String _seedKey = 'scenarios_seeded';

  final SharedPreferences _prefs;

  ScenarioRepository(this._prefs);

  /// Loads the store, seeding demo scenarios on the very first run.
  static Future<ScenarioRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ScenarioRepository(prefs);
    await repo._seedIfEmpty();
    return repo;
  }

  Future<void> _seedIfEmpty() async {
    if (_prefs.getBool(_seedKey) ?? false) return;
    await saveAll(mockScenarios());
    await _prefs.setBool(_seedKey, true);
  }

  /// Fetches the persisted scenario list in stored order.
  List<Scenario> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        Scenario.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the scenario list, preserving order.
  Future<void> saveAll(List<Scenario> scenarios) {
    final encoded = jsonEncode([for (final s in scenarios) s.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Clears the persisted scenario list.
  Future<void> clear() => saveAll(const []);
}
