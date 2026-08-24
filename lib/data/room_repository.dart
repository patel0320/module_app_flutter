// lib/data/room_repository.dart
//
// Local persistence layer for the ordered room list, mirroring
// lib/data/module_repository.dart. Rooms (id + name) are stored as a JSON
// list under a single shared_preferences key, preserving not just the rooms
// themselves but their presentation order across app restarts (brief 2.5).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'mock_data.dart';

class RoomRepository {
  static const String _storageKey = 'rooms';
  static const String _seedKey = 'rooms_seeded';

  final SharedPreferences _prefs;

  RoomRepository(this._prefs);

  /// Loads the store, seeding demo rooms on the very first run.
  static Future<RoomRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = RoomRepository(prefs);
    await repo._seedIfEmpty();
    return repo;
  }

  Future<void> _seedIfEmpty() async {
    if (_prefs.getBool(_seedKey) ?? false) return;
    await saveAll(mockRooms());
    await _prefs.setBool(_seedKey, true);
  }

  /// Fetches the persisted room list in stored (presentation) order.
  List<Room> fetch() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return [
      for (final item in decoded)
        Room.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Persists a full snapshot of the room list, preserving order.
  Future<void> saveAll(List<Room> rooms) {
    final encoded = jsonEncode([for (final r in rooms) r.toJson()]);
    return _prefs.setString(_storageKey, encoded);
  }

  /// Clears the persisted room list.
  Future<void> clear() => saveAll(const []);
}
