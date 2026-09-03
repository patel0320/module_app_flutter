// Tests for ModuleProtocolSelector: the firmware-driven choice between the
// Control API (doc/Soleux_Control_API_Command_Specification_v0.2.md) and the
// legacy TCP AT protocol (doc/PROTOCOLS.md §1).
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/models/models.dart';
import 'package:soleux_device_manager/services/module_status/module_command_protocol.dart';
import 'package:soleux_device_manager/services/module_status/module_protocol_selector.dart';

void main() {
  const selector = ModuleProtocolSelector();

  DeviceModule module({String? firmware, bool advertised = false}) =>
      DeviceModule(
        id: 'm1',
        name: 'Relay',
        type: ModuleType.relay,
        ipAddress: '192.168.1.10',
        status: ConnectionStatus.offline,
        roomName: 'Cabin',
        internalTempC: 0,
        firmware: firmware,
        apiPort: advertised ? 5008 : null,
        apiVersion: advertised ? 3 : null,
        caps: advertised ? const ['control_api_v3'] : const [],
      );

  test('pins a >= 7.12 module to the Control API', () {
    for (final fw in ['7.12', '7.15', '8.0', '7.12 Build :2']) {
      final d = selector.decide(module(firmware: fw));
      expect(d.kind, ModuleCommandProtocolKind.controlApi,
          reason: '$fw must select the Control API');
      expect(d.pinned, isTrue, reason: 'known firmware must pin the choice');
    }
  });

  test('pins a < 7.12 module to the legacy AT protocol', () {
    for (final fw in ['7.11', '7.10.9', '6.2', '1.20 Build :9']) {
      final d = selector.decide(module(firmware: fw));
      expect(d.kind, ModuleCommandProtocolKind.legacyAt,
          reason: '$fw must select the legacy AT protocol');
      expect(d.pinned, isTrue, reason: 'known firmware must pin the choice');
    }
  });

  test(
      'unknown firmware + Control API advertisement selects controlApi '
      'without pinning', () {
    final d = selector.decide(module(advertised: true));
    expect(d.kind, ModuleCommandProtocolKind.controlApi);
    expect(d.pinned, isFalse, reason: 'unknown firmware stays probeable');
  });

  test(
      'unknown firmware without advertisement defaults to legacyAt, '
      'without pinning', () {
    final d = selector.decide(module());
    expect(d.kind, ModuleCommandProtocolKind.legacyAt);
    expect(d.pinned, isFalse,
        reason: 'unknown firmware stays probeable (may still speak JSON)');
  });

  test('decideForFirmware returns null when the version is unknown', () {
    expect(selector.decideForFirmware(null), isNull);
    expect(selector.decideForFirmware('Build 42'), isNull);
    expect(selector.decideForFirmware(''), isNull);
  });
}
