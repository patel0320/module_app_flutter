// lib/services/module_status/module_protocol_selector.dart
//
// Pure policy for choosing the TCP command protocol of a module - the single
// source of truth for the migration boundary described in
// doc/Soleux_Control_API_Command_Specification_v0.2.md:
//
//   - firmware >= 7.12 (the Control API release gate) -> controlApi;
//   - firmware <  7.12                                -> legacyAt;
//   - unknown / unparseable firmware                  -> falls back to the
//     transport the module advertised during discovery (Control API port /
//     version / capabilities), else legacy AT, and is NOT pinned so the status
//     service can probe for the protocol the device actually speaks.
//
// Pinned selections are authoritative: a 7.12+ module is never spoken to with
// AT, and a pre-7.12 module is never spoken to with Control API JSON.
import '../../core/soleux/soleux_firmware_version.dart';
import '../../models/models.dart';
import 'module_command_protocol.dart';

/// The chosen wire protocol plus whether the choice is authoritative.
class ModuleProtocolDecision {
  /// The wire protocol to use.
  final ModuleCommandProtocolKind kind;

  /// True when [kind] is forced by a known firmware version. Pinned selections
  /// must not be probed or fallbacked across the boundary.
  final bool pinned;

  const ModuleProtocolDecision({required this.kind, required this.pinned});

  @override
  String toString() => 'ModuleProtocolDecision(${kind.label}, pinned: $pinned)';
}

/// Selects the [ModuleCommandProtocolKind] for a module.
class ModuleProtocolSelector {
  const ModuleProtocolSelector();

  /// Resolves the protocol for [module] per the firmware/discovery policy.
  ModuleProtocolDecision decide(DeviceModule module) {
    final fromFirmware = decideForFirmware(module.firmware);
    if (fromFirmware != null) return fromFirmware;

    // Unknown or unparseable firmware: trust discovery advertisement when the
    // device announced the Control API transport; otherwise default to the
    // legacy AT protocol as the probe starting point.
    return ModuleProtocolDecision(
      kind: module.isControlApiAdvertised
          ? ModuleCommandProtocolKind.controlApi
          : ModuleCommandProtocolKind.legacyAt,
      pinned: false,
    );
  }

  /// Distinguishes between a pinned controlApi / legacyAt for a *known*
  /// firmware version. Returns null when the firmware is unknown or
  /// unparseable, leaving the caller free to probe.
  ModuleProtocolDecision? decideForFirmware(String? firmware) {
    final version = SoleuxFirmwareVersion.tryParse(firmware);
    if (version == null) return null;
    return ModuleProtocolDecision(
      kind: version.supportsControlApi
          ? ModuleCommandProtocolKind.controlApi
          : ModuleCommandProtocolKind.legacyAt,
      pinned: true,
    );
  }
}
