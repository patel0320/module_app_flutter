// Tests for the firmware version value type and the Control API release gate
// (doc/Soleux_Control_API_Command_Specification_v0.2.md):
//
//   firmware >= 7.12 -> Control API command model
//   firmware <  7.12 -> legacy TCP AT (doc/PROTOCOLS.md §1)
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_firmware_version.dart';

void main() {
  group('SoleuxFirmwareVersion.tryParse', () {
    test('parses plain dotted versions', () {
      final v = SoleuxFirmwareVersion.tryParse('7.12');
      expect(v, isNotNull);
      expect(v!.parts, [7, 12]);
    });

    test('parses trailing build/tag text', () {
      final v = SoleuxFirmwareVersion.tryParse('1.20 Build :42');
      expect(v, isNotNull);
      expect(v!.parts, [1, 20]);
      expect(v.suffix, 'Build :42');
    });

    test('tolerates a leading v/V and version suffixes', () {
      expect(SoleuxFirmwareVersion.tryParse('V7.12.0-b1')!.parts, [7, 12, 0]);
      expect(SoleuxFirmwareVersion.tryParse('v2')!.parts, [2]);
    });

    test('returns null for unparseable values', () {
      expect(SoleuxFirmwareVersion.tryParse(null), isNull);
      expect(SoleuxFirmwareVersion.tryParse(''), isNull);
      expect(SoleuxFirmwareVersion.tryParse('  '), isNull);
      expect(SoleuxFirmwareVersion.tryParse('n/a'), isNull);
      expect(SoleuxFirmwareVersion.tryParse('Build 42'), isNull);
    });
  });

  group('compareTo / ordering', () {
    bool after(String a, String b) =>
        SoleuxFirmwareVersion.tryParse(a)!
            .compareTo(SoleuxFirmwareVersion.tryParse(b)!) >
        0;

    test('orders numerically, not lexically', () {
      expect(after('7.9', '7.11'), isFalse);
      expect(after('7.12', '7.9'), isTrue);
      expect(after('7.12', '7.12'), isFalse);
      expect(after('8.0', '7.12'), isTrue);
      expect(after('7.12.1', '7.12'), isTrue);
    });

    test('pad shorter versions with zero segments', () {
      expect(after('8', '7.12'), isTrue);
      expect(after('7.12', '7'), isTrue);
    });

    test('build tags do not change ordering', () {
      expect(
          SoleuxFirmwareVersion.tryParse('7.12 Build :1')!
              .compareTo(SoleuxFirmwareVersion.tryParse('7.12 Build :9')!),
          0);
    });
  });

  group('Control API release gate (7.12)', () {
    test('7.12 and newer support the Control API', () {
      for (final fw in [
        '7.12',
        '7.12.0',
        '7.15',
        '8.0',
        '7.12 Build :1',
        '12',
      ]) {
        expect(SoleuxFirmwareVersion.tryParse(fw)!.supportsControlApi, isTrue,
            reason: '$fw must be at/above the Control API gate');
      }
    });

    test('versions below 7.12 use the legacy AT model', () {
      for (final fw in ['7.11', '7.11.9', '7.10', '6.2', '1.20 Build :9']) {
        expect(SoleuxFirmwareVersion.tryParse(fw)!.supportsControlApi, isFalse,
            reason: '$fw must sit below the Control API gate');
      }
    });

    test('SoleuxControlApiPolicy.supportsControlApi mirrors the gate', () {
      expect(SoleuxControlApiPolicy.minimumFirmware, '7.12');
      expect(SoleuxControlApiPolicy.supportsControlApi('7.11'), isFalse);
      expect(SoleuxControlApiPolicy.supportsControlApi('7.12'), isTrue);
      expect(
          SoleuxControlApiPolicy.supportsControlApi('7.12 Build :3'), isTrue);
      expect(SoleuxControlApiPolicy.supportsControlApi('8.1'), isTrue);
      expect(SoleuxControlApiPolicy.supportsControlApi(null), isFalse);
      expect(SoleuxControlApiPolicy.supportsControlApi('unknown'), isFalse);
    });
  });
}
