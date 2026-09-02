// lib/services/module_status/module_heartbeat_service.dart
//
// Fleet-level UDP heartbeat monitor that drives each module's online/offline
// status from the Soleux heartbeat protocol
// (doc/Soleux_Network_Discovery_and_Heartbeat_Specification_v0.1.md §4).
//
// This is the "implement heartbeat logic for modules" layer: it keeps a
// stateful [SoleuxHeartbeatMonitor] for the currently configured fleet,
// refreshes the target set whenever the [ModuleStore] changes (module added,
// removed or re-addressed), records `lastSeenAt` on every valid pong, and
// maps the spec §4.4 availability state machine onto the app's
// [ConnectionStatus] only when the state actually transitions (so the UI does
// not churn with the 5 s ping cadence).
//
// Lifecycle mirror of [ModuleStatusScheduler]: it is started while the app is
// in the foreground (a UDP ping is far cheaper than a TCP socket and gives
// independent reachability evidence per spec §4.5) and stopped when the app
// backgrounds, where native background workers take over instead of
// aggressive 5-second polling.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/soleux/soleux_heartbeat.dart';
import '../../models/models.dart';
import '../module_store.dart';

/// Owns the heartbeat monitor for the configured module fleet.
class ModuleHeartbeatService {
  static ModuleHeartbeatService? _shared;
  static ModuleHeartbeatService get shared =>
      _shared ??= ModuleHeartbeatService(store: ModuleStore.shared);

  /// Creates an isolated service for tests (backed by the same monitor).
  @visibleForTesting
  static ModuleHeartbeatService forTesting(
          {required ModuleStore store, SoleuxHeartbeatMonitor? monitor}) =>
      ModuleHeartbeatService(store: store, monitor: monitor);

  final ModuleStore store;
  final SoleuxHeartbeatMonitor _monitor;

  bool _running = false;
  Timer? _commitDebounce;

  /// Exposed for tests that want to observe the raw availability transitions.
  void Function(HeartbeatTarget, HeartbeatAvailability)? onAvailability;

  /// The monitor backing this service (read-only access for tests that want
  /// to inject targets or query last-seen).
  SoleuxHeartbeatMonitor get monitor => _monitor;

  ModuleHeartbeatService(
      {required this.store, SoleuxHeartbeatMonitor? monitor})
      : _monitor = monitor ?? SoleuxHeartbeatMonitor() {
    _monitor.onState = _onState;
    _monitor.onPong = _onPong;
  }

  bool get running => _running;

  /// Starts monitoring the persisted fleet. Idempotent. Existing per-target
  /// state is preserved across re-starts because [SoleuxHeartbeatMonitor]
  /// keeps it keyed by module id.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    store.addListener(_onStoreChanged);
    // Keep the monitor in its running state so refreshTargets (below) is
    // allowed to schedule the fleet; targets arrive with the next refresh.
    _monitor.start(const []);
    await _refreshTargets();
  }

  /// Stops monitoring and drops every target (used when the app backgrounds).
  void stop() {
    if (!_running) return;
    _running = false;
    store.removeListener(_onStoreChanged);
    _monitor.clearTargets();
    _monitor.stop();
  }

  /// Re-runs a monitoring pass now (after a network change), without toggling
  /// the lifecycle state.
  Future<void> refresh() async {
    if (!_running) return;
    await _refreshTargets();
  }

  /// Most recent valid pong time for the module with [id], or null.
  DateTime? lastSeenFor(String moduleId) => _monitor.lastSeenAtFor(moduleId);

  void _onStoreChanged() {
    if (!_running) return;
    _refreshTargets().ignore();
  }

  /// Rebuilds the target list from the store. Targets are keyed by module id,
  /// so a module that keeps its id across a re-discovery keeps its counters.
  Future<void> _refreshTargets() async {
    await store.init();
    if (!_running) return;
    final targets = <HeartbeatTarget>[
      for (final module in store.modules)
        HeartbeatTarget(
          host: module.ipAddress,
          tcpPort: module.tcpPort,
          heartbeatPort: module.effectiveHeartbeatPort,
          key: module.id,
        ),
    ];
    if (targets.isNotEmpty) _monitor.refreshTargets(targets);
  }

  /// Every valid pong refreshes the module's `lastSeenAt` (spec §4.2) and is
  /// persisted with a short debounce so the 5 s cadence does not hammer disk.
  void _onPong(HeartbeatTarget target, SoleuxPong pong) {
    final module = store.byId(target.key);
    if (module == null) return;
    module.lastSeenAt = DateTime.now();
    _scheduleCommit();
  }

  /// Spec §4.4 transitions map onto [ConnectionStatus] only when the state
  /// actually changes (the monitor deduplicates identical states), keeping the
  /// UI stable across the ping interval. `unknown`/`suspect`/`rebooting` never
  /// downgrade a module that another layer (TCP Control API session) still
  /// considers healthy.
  void _onState(HeartbeatTarget target, HeartbeatAvailability state) {
    final module = store.byId(target.key);
    if (module == null) return;
    onAvailability?.call(target, state);
    switch (state) {
      case HeartbeatAvailability.online:
        module.status = ConnectionStatus.online;
        break;
      case HeartbeatAvailability.offline:
        module.status = ConnectionStatus.offline;
        break;
      case HeartbeatAvailability.unknown:
      case HeartbeatAvailability.suspect:
      case HeartbeatAvailability.rebooting:
        // Do not flicker the fleet's green/red dot on a transiently aging
        // heartbeat; the offline->online and online->offline transitions are
        // handled above.
        return;
    }
    store.commit().ignore();
  }

  /// Coalesces frequent per-pong writes into a single delayed commit.
  void _scheduleCommit() {
    _commitDebounce?.cancel();
    _commitDebounce =
        Timer(const Duration(milliseconds: 200), () => store.commit().ignore());
  }
}