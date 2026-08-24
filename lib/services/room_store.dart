// lib/services/room_store.dart
//
// App-wide, single source of truth for the ordered list of rooms/zones.
// Rooms can be created, renamed, reordered and deleted from the Rooms screen
// (brief 2.5), and the same order is surfaced on the Home screen's rooms strip.
// Both screens read/write this store and rebuild via ListenableBuilder.
//
// The in-memory list is persisted through [RoomRepository] on every mutation
// (including reordering), so room order survives app restarts.
import 'package:flutter/foundation.dart';

import '../data/room_repository.dart';
import '../models/models.dart';

class RoomStore extends ChangeNotifier {
  RoomStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static RoomStore shared = RoomStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static RoomStore forTesting() => RoomStore._();

  RoomRepository? _repo;
  List<Room> _rooms = [];
  bool _loaded = false;

  /// The current ordered rooms (unmodifiable view).
  List<Room> get rooms => List.unmodifiable(_rooms);

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get isEmpty => _rooms.isEmpty;

  /// Loads the persisted room list exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _repo = await RoomRepository.load();
      _rooms = _repo!.fetch();
    } catch (_) {
      _rooms = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists the current list (preserving order) and broadcasts a change.
  Future<void> _commit() async {
    await _repo?.saveAll(_rooms);
    notifyListeners();
  }

  /// Adds a room with [name] and persists the change.
  Future<void> add(String name) async {
    await init();
    _rooms.add(
      Room(id: 'room-${DateTime.now().millisecondsSinceEpoch}', name: name),
    );
    await _commit();
  }

  /// Renames [room] to [name] and persists the change.
  Future<void> rename(Room room, String name) async {
    await init();
    room.name = name;
    await _commit();
  }

  /// Removes [room] and persists the change.
  Future<void> remove(Room room) async {
    await init();
    _rooms.remove(room);
    await _commit();
  }

  /// Moves the item at [oldIndex] to [newIndex] (ReorderableListView
  /// semantics, where newIndex is the target "before" slot) and persists the
  /// new order.
  Future<void> reorder(int oldIndex, int newIndex) async {
    await init();
    if (newIndex > oldIndex) newIndex -= 1;
    final room = _rooms.removeAt(oldIndex);
    _rooms.insert(newIndex, room);
    await _commit();
  }
}
