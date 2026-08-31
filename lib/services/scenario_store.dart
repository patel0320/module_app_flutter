// lib/services/scenario_store.dart
//
// App-wide, single source of truth for the scenario list. Every screen that
// needs scenarios (Scenarios list, Home quick-access, editor) reads from this
// store and rebuilds via ListenableBuilder / addListener.
//
// The in-memory list is persisted through [ScenarioRepository] on every
// mutation so scenario edits survive app restarts.
import 'package:flutter/foundation.dart';

import '../data/scenario_repository.dart';
import '../models/models.dart';

class ScenarioStore extends ChangeNotifier {
  ScenarioStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static ScenarioStore shared = ScenarioStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static ScenarioStore forTesting() => ScenarioStore._();

  ScenarioRepository? _repo;
  List<Scenario> _scenarios = [];
  bool _loaded = false;

  /// The current scenarios (unmodifiable view).
  List<Scenario> get scenarios => List.unmodifiable(_scenarios);

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get isEmpty => _scenarios.isEmpty;

  /// Loads the persisted scenario list exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _repo = await ScenarioRepository.load();
      _scenarios = _repo!.fetch();
    } catch (e, st) {
      debugPrint('ScenarioStore: loading scenarios failed: $e\n$st');
      _scenarios = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists the current list and broadcasts a change.
  Future<void> commit() async {
    await _repo?.saveAll(_scenarios);
    notifyListeners();
  }

  /// Adds [scenario] (or replaces the one with the same id) and persists.
  Future<void> upsert(Scenario scenario) async {
    await init();
    final index = _scenarios.indexWhere((s) => s.id == scenario.id);
    if (index >= 0) {
      _scenarios[index] = scenario;
    } else {
      _scenarios.add(scenario);
    }
    await commit();
  }

  /// Removes the scenario with [id] and persists.
  Future<void> remove(String id) async {
    await init();
    _scenarios.removeWhere((s) => s.id == id);
    await commit();
  }

  /// Moves the item at [oldIndex] to [newIndex] using ReorderableListView
  /// [onReorderItem] semantics (newIndex is the drop slot after the item has
  /// been removed from [oldIndex]), then persists.
  Future<void> reorder(int oldIndex, int newIndex) async {
    await init();
    await _move(oldIndex, newIndex);
  }

  /// Moves the scenario with [id] so it lands before the item currently at
  /// global index [targetIndex] (or to the end when targetIndex == length),
  /// then persists. This lets a filtered view (e.g. Home's show-in-home subset)
  /// reorder within the full list.
  Future<void> move(String id, int targetIndex) async {
    await init();
    final oldIndex = _scenarios.indexWhere((s) => s.id == id);
    if (oldIndex < 0) return;
    if (targetIndex > oldIndex) targetIndex -= 1;
    await _move(oldIndex, targetIndex);
  }

  Future<void> _move(int oldIndex, int newIndex) async {
    final scenario = _scenarios.removeAt(oldIndex);
    _scenarios.insert(newIndex, scenario);
    await commit();
  }
}
