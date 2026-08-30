// Tests for the Soleux Layer-2 (DCP) commissioning protocol builders
// (doc/Soleux-Network-Discovery-and-DCP.md §2).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/discovery/dcp_discovery.dart';
import 'package:soleux_device_manager/core/soleux/soleux_device_family.dart';

void main() {
  group('MAC handling', () {
    test('normalizeMac tolerates case and separators', () {
      expect(normalizeMac('02:81:F9:30:81:F9'), '02:81:F9:30:81:F9');
      expect(normalizeMac('02-81-f9-30-81-f9'), '02:81:F9:30:81:F9');
      expect(normalizeMac('0281f93081f9'), '02:81:F9:30:81:F9');
      expect(normalizeMac('FF:FF:FF:FF:FF:FF'), 'FF:FF:FF:FF:FF:FF');
      expect(normalizeMac('not-a-mac'), isNull);
      expect(normalizeMac(''), isNull);
    });

    test('macToBytes produces 6 network-order bytes', () {
      expect(macToBytes('02:81:F9:30:81:F9'), [0x02, 0x81, 0xF9, 0x30, 0x81, 0xF9]);
      expect(macToBytes('FF:FF:FF:FF:FF:FF'),
          [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
    });
  });

  group('DcpMessage', () {
    test('identify carries soleux_l2, op and nonce', () {
      final json = jsonDecode(DcpMessage.identify(nonce: 'corr-1'));
      expect(json['soleux_l2'], 1);
      expect(json['op'], 'identify');
      expect(json['nonce'], 'corr-1');
    });

    test('set_ipv4 requires ip/mask/gateway and echoes the target MAC', () {
      final json = jsonDecode(DcpMessage.setIpv4(
        targetMac: '02-81-F9-30-81-F9',
        ip: '10.100.20.42',
        mask: '255.255.255.0',
        gateway: '10.100.20.1',
        nonce: 'corr-2',
      ));
      expect(json['op'], 'set_ipv4');
      expect(json['target'], '02:81:F9:30:81:F9');
      expect(json['ip'], '10.100.20.42');
      expect(json['mask'], '255.255.255.0');
      expect(json['gateway'], '10.100.20.1');
    });

    test('reboot targets a MAC by unicast', () {
      final json = jsonDecode(DcpMessage.reboot(
          targetMac: '02:81:F9:30:81:F9', nonce: 'corr-3'));
      expect(json['op'], 'reboot');
      expect(json['target'], '02:81:F9:30:81:F9');
    });
  });

  group('DcpFrameBuilder', () {
    test('header carries 6-byte dst, 6-byte src and EtherType 0x88B5', () {
      const builder = DcpFrameBuilder();
      final frame = builder.build(
        destinationMac: '02:81:F9:30:81:F9',
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        jsonPayload: DcpMessage.identify(nonce: 'x'),
      );
      expect(frame.take(14), [
        0x02, 0x81, 0xF9, 0x30, 0x81, 0xF9, // dst
        0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, // src
        0x88, 0xB5, // EtherType 0x88B5 network byte order
      ]);
    });

    test('zero-pads to the Ethernet minimum frame size', () {
      const builder = DcpFrameBuilder();
      final frame = builder.build(
        destinationMac: 'FF:FF:FF:FF:FF:FF',
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        jsonPayload: '{"soleux_l2":1,"op":"identify","nonce":"x"}',
      );
      expect(frame.length, kEthernetMinimumFrameSize);
      // Trailing zero padding; payload is recoverable after trimming NULs.
      final payloadText = utf8.decode(frame.sublist(14));
      final end = payloadText.indexOf('\u0000');
      final recovered = end == -1 ? payloadText : payloadText.substring(0, end);
      final decoded = jsonDecode(recovered);
      expect(decoded['op'], 'identify');
    });
  });

  group('DcpFrame.parsePayload + identity', () {
    DcpFrame identityFrame() => DcpFrame.parsePayload(jsonEncode({
          'soleux_l2': 1,
          'op': 'identity',
          'nonce': 'client-generated-correlation-value',
          'guid': '579E6EA1-2F64-4CDE-8190-1CD3646EFAA1',
          'mac': '02:81:F9:30:81:F9',
          'name': 'Plant Room Relays',
          'serial': '0000000012345678',
          'firmware': '7.10',
          'port': 5005,
          'ip': '10.100.20.42',
          'mask': '255.255.255.0',
          'gateway': '10.100.20.1',
        }))!;

    test('parses identity and maps the GUID to a family', () {
      final identity = DcpIdentity.fromFrame(identityFrame());
      expect(identity.nonce, 'client-generated-correlation-value');
      expect(identity.family, SoleuxDeviceFamily.relayModule);
      expect(identity.mac, '02:81:F9:30:81:F9');
      expect(identity.serial, '0000000012345678');
      expect(identity.firmware, '7.10');
      expect(identity.port, 5005);
      expect(identity.hasUsableIp, isTrue);
    });

    test('unaddressed devices report no usable IP', () {
      final frame = DcpFrame.parsePayload(jsonEncode({
        'soleux_l2': 1,
        'op': 'identity',
        'nonce': 'n',
        'mac': '02:81:F9:30:81:F9',
        'ip': '0.0.0.0',
        'mask': '0.0.0.0',
        'gateway': '0.0.0.0',
      }))!;
      final identity = DcpIdentity.fromFrame(frame);
      expect(identity.hasUsableIp, isFalse);
    });

    test('parses set_result ok and error', () {
      final ok = DcpResult.fromFrame(DcpFrame.parsePayload(jsonEncode({
        'soleux_l2': 1,
        'op': 'set_result',
        'status': 'ok',
        'message': 'static IPv4 settings saved',
      }))!);
      expect(ok.ok, isTrue);
      expect(ok.message, 'static IPv4 settings saved');

      final err = DcpResult.fromFrame(DcpFrame.parsePayload(jsonEncode({
        'soleux_l2': 1,
        'op': 'set_result',
        'status': 'error',
        'message': 'invalid subnet mask',
      }))!);
      expect(err.ok, isFalse);
    });

    test('rejects non-protocol frames', () {
      expect(DcpFrame.parsePayload('{"op":"identity"}'), isNull);
      expect(DcpFrame.parsePayload('not json'), isNull);
    });
  });

  test('DcpSupport: no raw-socket backend is wired on stock Flutter', () async {
    expect(await DcpSupport.available(), isFalse);
    expect(DcpSupport.unavailableReason(), isNotEmpty);
  });
}