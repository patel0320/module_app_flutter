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
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../module_store.dart';
import 'module_command_service.dart';
import 'module_status_fetcher.dart';
import 'module_tcp_service.dart';
import 'soleux_json_fetcher.dart';
import 'soleux_json_service.dart';

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

  /// Persistent per-module JSON command/status units (Soleux J: protocol).
  final Map<String, SoleuxJsonService> _jsonUnits = {};

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

  /// The live Soleux JSON unit driving [moduleId], or null when the device is
  /// not JSON-capable (or not yet probed).
  SoleuxJsonService? jsonCommandServiceFor(String moduleId) =>
      _jsonUnits[moduleId];

  /// Sends a raw legacy `AT+...` control command through whichever persistent
  /// unit is active for [moduleId]: the Soleux JSON unit for JSON-capable
  /// devices, the legacy AT+ unit otherwise. Returns true when the device
  /// acknowledged with `OK`.
  Future<bool> sendLegacyCommand(String moduleId, String command) async {
    final jsonUnit = _jsonUnits[moduleId];
    if (jsonUnit != null) {
      if (!jsonUnit.isConnected) return false;
      try {
        final raw = await jsonUnit.legacy(command);
        return raw.endsWith('OK');
      } catch (_) {
        return false;
      }
    }
    final atUnit = _units[moduleId];
    if (atUnit != null) {
      return atUnit.command(command);
    }
    return false;
  }

  /// Turns an output on (zero-based channel) via the active transport.
  Future<bool> turnOnOutput(String moduleId, int index) =>
      sendLegacyCommand(moduleId, 'AT+ON:$index\r');

  /// Turns an output off (zero-based channel) via the active transport.
  Future<bool> turnOffOutput(String moduleId, int index) =>
      sendLegacyCommand(moduleId, 'AT+OFF:$index\r');

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

  /// Tears down the live command/status unit for [moduleId]. Used when a
  /// module is removed so its socket/reconnect timers stop and the fleet
  /// counts reflect exactly the modules that remain.
  void removeModule(String moduleId) {
    _units.remove(moduleId)?.dispose();
    _disposeJsonUnit(moduleId);
  }

  /// Closes every persistent socket (and stops each unit's auto-reconnect)
  /// while keeping the units themselves alive so the app can resume quickly.
  /// Used by the lifecycle scheduler when the app moves to the background,
  /// where keeping sockets open wastes battery.
  Future<void> suspendAll() async {
    for (final unit in _units.values) {
      await unit.disconnect();
    }
    for (final unit in _jsonUnits.values) {
      await unit.disconnect();
    }
  }

  /// Brings every module back to the persistent-socket live mode. Disconnected
  /// sockets are reopened and a fresh status pass is run. Safe to call when
  /// sockets are already live (a no-op reconnect + coalesced refresh).
  Future<ModuleStatusResult> resumeAll() async {
    await store.init();
    for (final module in store.modules) {
      final unit = _units[module.id];
      if (unit != null) {
        await unit.connect();
      }
      final jsonUnit = _jsonUnits[module.id];
      if (jsonUnit != null) {
        await jsonUnit.connect();
      }
    }
    return refreshAll();
  }

  /// Lightweight background poll: for every module, opens a one-shot TCP
  /// socket, sends an `AT\r` ping, awaits the `OK` terminator and closes it
  /// again - no persistent connection is kept. Each module's online/offline
  /// slot is updated in the store and committed once at the end.
  Future<ModuleStatusResult> pollAll() async {
    await store.init();
    final modules = store.modules;
    final online = <DeviceModule>[];
    final offline = <DeviceModule>[];

    for (final module in modules) {
      final ok = await _pollConnectivity(module);
      ok ? online.add(module) : offline.add(module);
    }

    await store.commit();
    _lastResult = ModuleStatusResult(online: online, offline: offline);
    return _lastResult!;
  }

  /// Opens a temporary socket to [module] and pings it for a single `OK`,
  /// closing it immediately after. Returns whether it answered. Unsupported
  /// module types are treated as offline.
  Future<bool> _pollConnectivity(DeviceModule module) async {
    final live = store.byId(module.id) ?? module;
    if (_fetchers.forType(module.type) == null) {
      live.status = ConnectionStatus.offline;
      return false;
    }

    Socket? socket;
    var reachable = false;
    try {
      socket =
          await Socket.connect(live.ipAddress, live.tcpPort, timeout: timeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      socket.write('AT\r');

      final buffer = StringBuffer();
      final done = Completer<void>();
      final timer = Timer(timeout, () {
        if (!done.isCompleted) done.complete();
      });

      socket.listen(
        (bytes) {
          buffer.write(utf8.decode(bytes));
          final raw = buffer.toString().trimRight();
          if (raw.endsWith('\r\nOK') || raw.endsWith('\r\nERROR')) {
            if (!done.isCompleted) done.complete();
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (Object _) {
          if (!done.isCompleted) done.complete();
        },
      );

      await done.future;
      timer.cancel();
      reachable = buffer.toString().trimRight().endsWith('\r\nOK');
    } catch (_) {
      reachable = false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {/* ignore */}
    }

    live.status =
        reachable ? ConnectionStatus.online : ConnectionStatus.offline;
    return reachable;
  }

  Future<bool> _refreshOne(DeviceModule module) async {
    // The store may hold a newer instance of the same module; operate on that
    // live object so mutations propagate to every screen.
    final live = store.byId(module.id) ?? module;

    final fetcher = _fetchers.forType(module.type);
    if (fetcher == null) {
      // Unsupported module type - no status probe exists, so it cannot be
      // confirmed reachable; mark it offline so the UI represents it clearly.
      live.status = ConnectionStatus.offline;
      return false;
    }

    // Optimistically reset the module to offline so the UI never shows a stale
    // "online" from a previous seed/run while this probe is in flight; the
    // module is only flipped back to online once the full dump is acknowledged.
    live.status = ConnectionStatus.offline;

    // Soleux JSON path first (the recommended protocol for new mobile
    // clients), falling back to the legacy AT+ dump when the device does not
    // answer a JSON `hello`.
    final jsonOk = await _refreshOneJson(live);
    if (jsonOk == true) {
      live.status = ConnectionStatus.online;
      // A JSON-capable device must not keep a duplicate legacy AT+ unit (and
      // its second socket) around.
      _units.remove(live.id)?.dispose();
      return true;
    }
    if (jsonOk == false) {
      // Connected but the JSON protocol was rejected - the device is not a
      // current Soleux JSON device; report unreachable/unsupported so the AT
      // path is not silently closed over.
      return false;
    }

    // Legacy AT+ path.
    final unit = _ensureUnit(live, fetcher);
    unit.attach(live);

    try {
      await unit.connect();
      debugPrint('Module ${module.name} (${module.id}) connected');
      if (!unit.isConnected) {
        return false;
      }
      debugPrint('Module ${module.name} (${module.id}) connected, fetching...');
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

  /// Attempts the Soleux JSON `hello` + `get_relay_configuration` probe.
  ///
  /// Returns:
  ///   - `true`  when the device answered the JSON protocol and the dump was
  ///             fetched;
  ///   - `false` when the JSON protocol was definitively rejected (connected
  ///             but no `ok` hello, or the socket is unreachable);
  ///   - `null`  when the TCP path is fine but no JSON `hello` arrived in time
  ///             - a legacy device, so the caller falls back to AT+.
  Future<bool?> _refreshOneJson(DeviceModule live) async {
    final unit = _ensureJsonUnit(live);
    await unit.connect();
    if (!unit.isConnected) {
      return false;
    }

    const fetcher = SoleuxJsonFetcher();
    try {
      final hello = await unit.hello(timeout: _jsonHelloTimeout);
      if (!hello.ok) return false;
      final helloData = SoleuxHelloData.fromResult(hello.result ?? {});
      fetcher.apply(live, helloData);

      final config =
          await unit.getRelayConfiguration(timeout: const Duration(seconds: 3));
      if (config.ok) {
        fetcher.applyConfiguration(
            live, SoleuxRelayConfiguration.fromResult(config.result ?? {}));
        _scheduleCommit();
      }
      return true;
    } on TimeoutException {
      // No JSON `hello` within the window - this is a legacy protocol device;
      // drop the JSON unit and let the AT+ path take over.
      debugPrint('Module ${live.name} (${live.id}) did not answer JSON hello; '
          'falling back to legacy AT+');
      _disposeJsonUnit(live.id);
      return null;
    } catch (e) {
      debugPrint('Module ${live.name} (${live.id}) JSON probe failed: $e');
      return false;
    }
  }

  /// Per-module timeout for a JSON `hello` round-trip.
  static const Duration _jsonHelloTimeout = Duration(seconds: 2);

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

  /// Gets the persistent Soleux JSON unit for [module], creating (and wiring)
  /// it the first time. Its live legacy/event lines are folded into the
  /// module's channel state and its connect/disconnect transitions flip the
  /// online status.
  SoleuxJsonService _ensureJsonUnit(DeviceModule module) {
    final existing = _jsonUnits[module.id];
    if (existing != null) return existing;

    final unit = SoleuxJsonService(
      connection: ModuleTcpConnection(
        host: module.ipAddress,
        port: module.tcpPort,
        timeout: timeout,
      ),
    );
    // Unsolicited `OUT:`/`IN:` state pushes keep the channel list live.
    unit.eventStream.listen((event) {
      final live = store.byId(module.id);
      if (live == null) return;
      if (event.channel != null &&
          event.state != null &&
          event.channel! >= 0 &&
          event.channel! < live.channels.length) {
        live.channels[event.channel!].isOn = event.state!;
        _scheduleCommit();
      }
    });
    // Connect/disconnect -> flip the module's online status.
    unit.connectionStateStream.listen((connected) {
      final live = store.byId(module.id);
      if (live == null) return;
      live.status =
          connected ? ConnectionStatus.online : ConnectionStatus.offline;
      _scheduleCommit();
    });

    _jsonUnits[module.id] = unit;
    return unit;
  }

  void _disposeJsonUnit(String moduleId) {
    _jsonUnits.remove(moduleId)?.dispose();
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
    for (final unit in _jsonUnits.values) {
      unit.dispose();
    }
    _jsonUnits.clear();
  }
}
