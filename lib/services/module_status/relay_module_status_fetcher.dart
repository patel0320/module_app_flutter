// lib/services/module_status/relay_module_status_fetcher.dart
//
// Status fetcher for the standard relay / PDU module, implemented against the
// TCP ASCII protocol in doc/PROTOCOLS.md §1 (commands #2, #3, #6, #14).
//
// The base class reconciles temperature, output/input counts, output/input
// states and module identity; this subclass only states which commands expose
// that topology for a standard relay.
import '../../models/models.dart';
import 'base_module_status_fetcher.dart';
import 'pdu_protocol.dart';

class RelayModuleStatusFetcher extends BaseModuleStatusFetcher {
  const RelayModuleStatusFetcher();

  @override
  ModuleType get type => ModuleType.relay;

  @override
  List<String> get fetchCommands => const [
        PduAtCommands.version, // AT+VER      identity + RELAY_COUNT
        PduAtCommands.temperature, // AT+TEMP      SYSTEMP
        PduAtCommands.allOutputStates, // AT+OUTSTAT  OUT:<pin>:<ON|OFF>
        PduAtCommands.allInputStates, // AT+INSTAT   IN:<pin>:<ON|OFF>
      ];
}
