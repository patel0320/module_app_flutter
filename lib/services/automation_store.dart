// lib/services/automation_store.dart
//
// App-wide, single source of truth for the automation list. Every screen that
// needs automations (Automations list, editor) reads from this store and
// rebuilds via ListenableBuilder / addListener.
//
// The in-memory list is persisted through [AutomationRepository] on every
// mutation so automation edits survive app restarts.
import 'package:flutter/foundation.dart';

import '../data/automation_repository.dart';
import '../models/models.dart';

class AutomationStore extends ChangeNotifier {
  AutomationStore._();

  /// App-wide shared instance used by the launch path and every screen.
  static AutomationStore shared = AutomationStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static AutomationStore forTesting() => AutomationStore._();

  AutomationRepository? _repo;
  List<Automation> _automations = [];
  bool _loaded = false;

  /// The current automations (unmodifiable view).
  List<Automation> get automations => List.unmodifiable(_automations);

  /// True once [init] has completed (successfully or not).
  bool get loaded => _loaded;

  bool get isEmpty => _automations.isEmpty;

  /// Loads the persisted automation list exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _repo = await AutomationRepository.load();
      _automations = _repo!.fetch();
    } catch (e, st) {
      debugPrint('AutomationStore: loading automations failed: $e\n$st');
      _automations = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Persists the current list and broadcasts a change.
  Future<void> commit() async {
    await _repo?.saveAll(_automations);
    notifyListeners();
  }

  /// Adds [automation] (or replaces the one with the same id) and persists.
  Future<void> upsert(Automation automation) async {
    await init();
    final index = _automations.indexWhere((a) => a.id == automation.id);
    if (index >= 0) {
      _automations[index] = automation;
    } else {
      _automations.add(automation);
    }
    await commit();
  }

  /// Removes the automation with [id] and persists.
  Future<void> remove(String id) async {
    await init();
    _automations.removeWhere((a) => a.id == id);
    await commit();
  }

  /// Replaces the entire automation list with [automations] and persists it.
  /// Used by the backup/restore flow to apply a restored rule set wholesale.
  Future<void> replaceAll(List<Automation> automations) async {
    await init();
    _automations
      ..clear()
      ..addAll(automations);
    await commit();
  }
}
