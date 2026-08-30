// Tests for the Soleux UDP discovery v2 request/response parsing layers of
// ModuleDiscovery (doc/Soleux-Network-Discovery-and-DCP.md §1).
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/discovery/module_discovery.dart';
import 'package:soleux_device_manager/core/soleux/soleux_device_family.dart';

void main() {
  group('discovery constants (v2)', () {
    test('request GUID and protocol version match the doc', () {
      expect(ModuleDiscovery.discoveryPort, 8000);
      expect(ModuleDiscovery.requestGuid,
          '8C93472D-2EF0-4B82-BE96-4FBBED57783F');
      expect(ModuleDiscovery.requestVersion, '2.0');
    });
  });

  group('parseIdentityResponse', () {
    test('parses the Relay Module example response by field name', () {
      final module = DiscoveredModule.parseIdentityResponse(
          'GUID:579E6EA1-2F64-4CDE-8190-1CD3646EFAA1\r\n'
          'VER:7.10\r\n'
          'PORT:5005\r\n'
          'SN:0000000012345678\r\n'
          'NAME:Plant Room Relays\r\n',
          '10.100.20.42');
      expect(module, isNotNull);
      expect(module!.guid, '579E6EA1-2F64-4CDE-8190-1CD3646EFAA1');
      expect(module.family, SoleuxDeviceFamily.relayModule);
      expect(module.version, '7.10');
      expect(module.tcpPort, 5005);
      expect(module.serial, '0000000012345678');
      expect(module.name, 'Plant Room Relays');
      expect(module.ip, '10.100.20.42');
      expect(module.heartbeatPort, 5007);
    });

    test('parses the Dimmer example response', () {
      final module = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\n'
          'VER:7.10\r\n'
          'PORT:5005\r\n'
          'SN:0000000012349999\r\n'
          'NAME:Lobby Dimmer\r\n',
          '10.100.20.43');
      expect(module!.family, SoleuxDeviceFamily.dimmer);
      expect(module.name, 'Lobby Dimmer');
    });

    test('accepts legacy `Port` casing (PDU V1.0)', () {
      final module = DiscoveredModule.parseIdentityResponse(
          'GUID:B4A6B160-0CBA-4BD8-873D-EDC9DF895C26\r\n'
          'Port:5100\r\n'
          'SN:0000000011111111\r\n'
          'NAME:Legacy Rack PDU\r\n',
          '10.100.20.44');
      expect(module!.family, SoleuxDeviceFamily.pduV1);
      expect(module.tcpPort, 5100);
    });

    test('tolerates mixed line order and ignores unknown fields', () {
      final module = DiscoveredModule.parseIdentityResponse(
          'NAME:Soleux PDU 10k\r\n'
          'FUTURE_FIELD:something\r\n'
          'SN:42\r\n'
          'GUID:A728DD7D-0DEB-49B9-9B8B-A4556771815F\r\n'
          'VER:8.0\r\n'
          'PORT:5005\r\n',
          '10.0.0.9');
      expect(module!.family, SoleuxDeviceFamily.pdu10kw);
      expect(module.name, 'Soleux PDU 10k');
      expect(module.version, '8.0');
    });

    test('requires a GUID; unknown GUIDs are still surfaced (family null)', () {
      expect(DiscoveredModule.parseIdentityResponse('VER:7.0\r\n', '1.2.3.4'),
          isNull);
      final unknown = DiscoveredModule.parseIdentityResponse(
          'GUID:11111111-2222-3333-4444-555555555555\r\nPORT:5005\r\n',
          '1.2.3.4');
      expect(unknown!.family, isNull);
      expect(unknown.tcpPort, 5005);
    });

    test('defaults the port to 5005 when absent', () {
      final module = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\nSN:1\r\n',
          '1.2.3.4');
      expect(module!.tcpPort, SoleuxConstants.defaultCommandPort);
    });
  });

  group('dedupeKey', () {
    test('prioritises serial number over GUID+IP', () {
      final a = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\nSN:S1\r\n',
          '10.0.0.1')!;
      final b = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\nSN:S1\r\n',
          '10.0.0.99')!;
      expect(a.dedupeKey, b.dedupeKey);
      expect(a.dedupeKey, 'sn:S1');
    });

    test('falls back to GUID+IP when no serial', () {
      final a = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\n', '10.0.0.1')!;
      final b = DiscoveredModule.parseIdentityResponse(
          'GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91\r\n', '10.0.0.2')!;
      expect(a.dedupeKey, isNot(b.dedupeKey));
    });
  });
}