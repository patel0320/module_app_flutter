// lib/services/module_status/module_status_fetcher.dart
//
// Expandable contract for turning raw PDU responses into live module state.
//
// Each [ModuleType] gets its own fetcher so the transport + status service stay
// module-agnostic. Only the *standard relay* fetcher exists today (see
// relay_module_status_fetcher.dart, driven by PROTOCOLS.md §1); dimmer /
// temperature / blind fetchers can be added later by implementing this
// interface and registering it - no changes to the service or transport.
import '../../models/models.dart';
import 'pdu_protocol.dart';
import 'relay_module_status_fetcher.dart';

/// Fetches + applies the live status for one module type.
abstract class ModuleStatusFetcher {
  /// The module type this fetcher is responsible for.
  ModuleType get type;

  /// `AT+...` commands issued sequentially to capture the full status dump.
  List<String> get fetchCommands;

  /// Persists the parsed responses into [module] (status, temperature, per
  /// channel on/off) once every command returned `OK`.
  void apply(DeviceModule module, List<PduResponse> responses);
}

/// Registry keyed by [ModuleType]. Start with the relay fetcher registered and
/// extend by calling [register] for each new module type added later.
class ModuleStatusFetcherRegistry {
  final Map<ModuleType, ModuleStatusFetcher> _fetchers = {};

  ModuleStatusFetcherRegistry() {
    _registerBuiltIns();
  }

  void _registerBuiltIns() {
    register(const RelayModuleStatusFetcher());
  }

  /// Registers (or replaces) the fetcher for its module type.
  void register(ModuleStatusFetcher fetcher) => _fetchers[fetcher.type] = fetcher;

  /// Returns the fetcher for [type], or null if not yet implemented.
  ModuleStatusFetcher? forType(ModuleType type) => _fetchers[type];

  /// The set of module types the registry knows how to fetch today.
  Set<ModuleType> get supportedTypes => _fetchers.keys.toSet();
}
