// lib/data/automation_repository.dart
//
// Local persistence layer for the automation list, mirroring
// lib/data/scenario_repository.dart, lib/data/module_repository.dart and
// lib/data/room_repository.dart. Automations (IF...THEN... rules from brief
// section 2.4) are stored as a JSON list under a single shared_preferences
// key so edits made in the Automations list / editor survive app restarts.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class AutomationRepository {
  static const String _storageKey = 'automations';

  final SharedPreferences _prefs;

  AutomationRepository(this._prefs);

  /// Loads the store. The automation list starts empty on a fresh install.
  static Future<AutomationRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AutomationRepository(prefs);
  }

  /// Fetches the persisted automation list in stored order.
  List<Automation> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        Automation.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the automation list, preserving order.
  Future<void> saveAll(List<Automation> automations) {
    final encoded = jsonEncode([for (final a in automations) a.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Clears the persisted automation list.
  Future<void> clear() => saveAll(const []);
}
