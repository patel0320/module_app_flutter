// lib/services/module_status/module_status_service.dart
//
// App-level service that, on launch, connects to every configured module and
// keeps its live status flowing into the app-wide [ModuleStore] (which
// persists + notifies every screen).
//
// Restructured around the reference architecture (`at_command_service.dart` +
// `tcp_service.dart`): instead of opening a fresh socket per refresh and
// closing it again, each module keeps a persistent, auto-reconnecting
// [ModuleCommandService] (transport + command/status, mirroring the AT
// service) alive for the app's lifetime. The service holds one such unit per
// module and routes their live streams into the store:
//
//   - on connect the module pushes its full status dump; it is parsed
//     continuously and streamed into the store,
//   - unsolicited push broadcasts (state changes published by the module)
//     arrive on the same stream and update the module live,
//   - [refreshAll] / [refreshOne] remain the explicit "please re-ask for a
//     fresh dump now" entry points and also coalesce concurrent calls.
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../module_store.dart';
import 'module_command_service.dart';
import 'module_status_fetcher.dart';
import 'module_tcp_service.dart';

/// Outcome of a single status pass over the fleet.
class ModuleStatusResult {
  /// Modules reachable and that answered every command with `OK`.
  final List<DeviceModule> online;

  /// Modules whose connection failed (offline / unreachable / unsupported).
  final List<DeviceModule> offline;

  const ModuleStatusResult({required this.online, required this.offline});

  bool get allOnline => offline.isEmpty;
  int get total => online.length + offline.length;
}

class ModuleStatusService {
  /// Per-module timeout for the whole exchange.
  static const Duration defaultTimeout = Duration(seconds: 2);

  final ModuleStore store;
  final Duration timeout;
  final ModuleStatusFetcherRegistry _fetchers = ModuleStatusFetcherRegistry();

  bool _refreshing = false;
  ModuleStatusResult? _lastResult;
  Timer? _commitDebounce;

  /// Persistent per-module command/status units (transport + parsing).
  final Map<String, ModuleCommandService> _units = {};

  ModuleStatusService({required this.store, this.timeout = defaultTimeout});

  /// Shared service wired to the shared store, used by the launch path.
  static ModuleStatusService? _shared;
  static ModuleStatusService get shared =>
      _shared ??= ModuleStatusService(store: ModuleStore.shared);

  /// The outcome of the last completed pass, or null before the first refresh.
  ModuleStatusResult? get lastResult => _lastResult;

  bool get refreshing => _refreshing;

  /// Whether there is a fetcher for [type] (false = "not yet implemented").
  bool supports(ModuleType type) => _fetchers.forType(type) != null;

  /// Registers an additional module-type fetcher for future support. Existing
  /// sessions are unaffected; new sessions pick up the new fetcher.
  void registerFetcher(ModuleStatusFetcher fetcher) =>
      _fetchers.register(fetcher);

  /// The live command/status unit driving [moduleId], or null when the module
  /// type is unsupported or its unit has not been created yet.
  ModuleCommandService? commandServiceFor(String moduleId) => _units[moduleId];

  /// Ensures every module is connected and re-asks it for a fresh status dump,
  /// committing the fleet once. Concurrent calls are coalesced.
  Future<ModuleStatusResult> refreshAll() async {
    if (_refreshing) {
      return _lastResult ?? const ModuleStatusResult(online: [], offline: []);
    }
    _refreshing = true;

    try {
      await store.init();
      final modules = store.modules;
      final online = <DeviceModule>[];
      final offline = <DeviceModule>[];

      for (final module in modules) {
        final ok = await _refreshOne(module);
        ok ? online.add(module) : offline.add(module);
      }

      await store.commit();
      _lastResult = ModuleStatusResult(online: online, offline: offline);
    } finally {
      _refreshing = false;
    }
    return _lastResult!;
  }

  /// Re-asks a single [module] for a fresh status dump and commits. Returns
  /// true when the module answered every command with `OK`.
  Future<bool> refreshOne(DeviceModule module) async {
    final ok = await _refreshOne(module);
    await store.commit();
    return ok;
  }

  Future<bool> _refreshOne(DeviceModule module) async {
    final fetcher = _fetchers.forType(module.type);
    if (fetcher == null) {
      // Unsupported module type - leave untouched, treat as offline.
      return false;
    }

    // The store may hold a newer instance of the same module; operate on that
    // live object so mutations propagate to every screen.
    final live = store.byId(module.id) ?? module;
    final unit = _ensureUnit(live, fetcher);
    unit.attach(live);

    try {
      await unit.connect();
      debugPrint('Module ${module.name} (${module.id}) connected');
      if (!unit.isConnected) {
        live.status = ConnectionStatus.offline;
        return false;
      }
      final allOk = await unit.run(fetcher.fetchCommands);
      debugPrint('Module ${module.name} (${module.id}) refresh: $allOk');
      live.status = allOk ? ConnectionStatus.online : ConnectionStatus.offline;
      return allOk;
    } catch (e) {
      debugPrint('Module ${module.name} (${module.id}) refresh failed: $e');
      // Socket / protocol / timeout - module unreachable.
      live.status = ConnectionStatus.offline;
      return false;
    }
  }

  /// Gets the persistent unit for [module], creating (and wiring) it the first
  /// time. Its live streams are routed into the store on creation only.
  ModuleCommandService _ensureUnit(
      DeviceModule module, ModuleStatusFetcher fetcher) {
    final existing = _units[module.id];
    if (existing != null) return existing;

    final unit = ModuleCommandService(
      connection: ModuleTcpConnection(
        host: module.ipAddress,
        port: module.tcpPort,
        timeout: timeout,
      ),
      fetcher: fetcher,
      module: module,
    );
    // Live status parses -> stream into the store (persist + notify).
    unit.moduleStream.listen((_) => _scheduleCommit());
    // Connect/disconnect -> flip the module's online status.
    unit.connectionStateStream.listen((connected) {
      unit.module.status =
          connected ? ConnectionStatus.online : ConnectionStatus.offline;
      _scheduleCommit();
    });

    _units[module.id] = unit;
    return unit;
  }

  /// Coalesces the frequent, unsolicited stream updates into a single delayed
  /// store commit instead of persisting on every byte burst.
  void _scheduleCommit() {
    _commitDebounce?.cancel();
    _commitDebounce =
        Timer(const Duration(milliseconds: 150), () => store.commit().ignore());
  }

  void dispose() {
    _commitDebounce?.cancel();
    _commitDebounce = null;
    for (final unit in _units.values) {
      unit.dispose();
    }
    _units.clear();
  }
}
