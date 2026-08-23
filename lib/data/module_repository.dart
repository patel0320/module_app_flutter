// lib/data/module_repository.dart
//
// Local persistence layer for the module list. Modules are stored as a JSON
// list under a single shared_preferences key so the Configuration screen can
// add / edit / delete / fetch modules and have them survive app restarts
// without a backend (brief section 4.2 "Cached device list persisted locally").
//
// The first time the app runs an empty store is seeded with the demo modules
// from mock_data.dart so the prototype still shows examples out of the box.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'mock_data.dart';

/// Thrown when an operation targets a module id that is not in storage.
class ModuleNotFoundException implements Exception {
  final String moduleId;
  const ModuleNotFoundException(this.moduleId);

  @override
  String toString() => 'ModuleNotFoundException: no module with id "$moduleId"';
}

class ModuleRepository {
  static const String _storageKey = 'modules';
  static const String _seedKey = 'modules_seeded';

  final SharedPreferences _prefs;

  ModuleRepository(this._prefs);

  /// Loads the store, seeding demo modules on the very first run.
  static Future<ModuleRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ModuleRepository(prefs);
    await repo._seedIfEmpty();
    return repo;
  }

  Future<void> _seedIfEmpty() async {
    if (_prefs.getBool(_seedKey) ?? false) return;
    await saveAll(mockModules());
    await _prefs.setBool(_seedKey, true);
  }

  /// Fetches the persisted module list.
  List<DeviceModule> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        DeviceModule.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the module list.
  Future<void> saveAll(List<DeviceModule> modules) {
    final encoded = jsonEncode([for (final m in modules) m.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Adds a module to storage (inserts or updates if the id already exists).
  Future<void> add(DeviceModule module) {
    final modules = fetch();
    final index = modules.indexWhere((m) => m.id == module.id);
    if (index >= 0) {
      modules[index] = module;
    } else {
      modules.add(module);
    }
    return saveAll(modules);
  }

  /// Persists an edit to an existing module, identified by [moduleId].
  Future<void> update(String moduleId, DeviceModule module) {
    final modules = fetch();
    final index = modules.indexWhere((m) => m.id == moduleId);
    if (index < 0) throw ModuleNotFoundException(moduleId);
    modules[index] = module;
    return saveAll(modules);
  }

  /// Removes a module from storage by id.
  Future<void> delete(String moduleId) {
    final modules = fetch().where((m) => m.id != moduleId).toList();
    return saveAll(modules);
  }

  /// Clears the persisted module list.
  Future<void> clear() => saveAll(const []);
}
