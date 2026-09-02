// Tests for the Soleux Control API / JSON protocol codec
// (doc/Soleux_Control_API_Command_Specification_v0.2.md §"Transport and
// message envelope"). The default framing is the Control API envelope (a plain
// JSON object per line, no J: prefix, with the outer protocol field); the
// legacy `J:` framing is retained for pre-Control-API devices.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_json_protocol.dart';

void main() {
  group('SoleuxJsonRequest.encode', () {
    test('produces one CRLF-terminated Control API line (no J: prefix)', () {
      const request = SoleuxJsonRequest(id: 1, action: 'hello', params: {});
      expect(request.encode(),
          '{"protocol":2,"id":1,"action":"hello","params":{}}\r\n');
    });

    test('legacy framing keeps the J: prefix for pre-Control-API devices', () {
      const request = SoleuxJsonRequest(
          id: 1, action: 'hello', params: {}, legacyJPrefix: true);
      expect(request.encode(),
          'J:{"protocol":2,"id":1,"action":"hello","params":{}}\r\n');
    });

    test('advertises a custom protocol version when requested', () {
      const request = SoleuxJsonRequest(
          id: 1,
          action: 'hello',
          params: {},
          protocol: SoleuxProtocolVersion.target);
      expect(request.encode(),
          '{"protocol":3,"id":1,"action":"hello","params":{}}\r\n');
    });

    test('carries params verbatim', () {
      const request =
          SoleuxJsonRequest(id: 40, action: 'get_energy_history', params: {
        'parameter': 0,
        'start_date': '2026-08-01',
        'end_date': '2026-08-29',
      });
      final decoded = jsonDecode(request.encode());
      expect(decoded['id'], 40);
      expect(decoded['action'], 'get_energy_history');
      expect(decoded['params']['start_date'], '2026-08-01');
    });
  });

  group('SoleuxJsonResponse.parseFromBody', () {
    test('parses a successful hello response', () {
      final response = SoleuxJsonResponse.parseFromBody(
          '{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,'
          '"device":"relay_module","name":"Plant Room Relays",'
          '"input_count":8,"virtual_input_count":2,"output_count":8}}');
      expect(response.id, 1);
      expect(response.ok, isTrue);
      expect(response.protocol, 2);
      expect(response.result!['device'], 'relay_module');
      expect(response.result!['output_count'], 8);
    });

    test('PDU V1.0 may omit the outer protocol field', () {
      final response = SoleuxJsonResponse.parseFromBody(
          '{"id":1,"ok":true,"result":{"protocol":2,"device":"pdu_v1"}}');
      expect(response.id, 1);
      expect(response.protocol, isNull);
      expect(response.result!['device'], 'pdu_v1');
    });

    test('accepts numeric-string ids per the envelope id type', () {
      final response =
          SoleuxJsonResponse.parseFromBody('{"protocol":3,"id":"42","ok":false,'
              '"error":{"code":"invalid_request","message":"bad channel"}}');
      expect(response.id, 42);
      expect(response.ok, isFalse);
    });

    test('rejects a non-numeric id', () {
      expect(
          () => SoleuxJsonResponse.parseFromBody(
              '{"protocol":3,"id":"mobile-1","ok":true,"result":{}}'),
          throwsFormatException);
    });

    test('failed requests carry error value/object', () {
      final asString = SoleuxJsonResponse.parseFromBody(
          '{"protocol":2,"id":10,"ok":false,"error":"cannot rebind port"}');
      expect(asString.ok, isFalse);
      expect(asString.error!.summary, 'cannot rebind port');

      final asObject =
          SoleuxJsonResponse.parseFromBody('{"protocol":2,"id":10,"ok":false,'
              '"error":{"code":"internal_error","message":"delay and runtime '
              'values must be between 0 and 65000"}}');
      expect(asObject.error!.code, 'internal_error');
      expect(asObject.error!.message, contains('65000'));
    });

    test('rejects non-object payloads', () {
      expect(() => SoleuxJsonResponse.parseFromBody('[1,2]'),
          throwsFormatException);
      expect(() => SoleuxJsonResponse.parseFromBody('"hi"'),
          throwsFormatException);
    });
  });

  group('SoleuxJsonResponse.maybeParse', () {
    test('returns null for non-JSON lines (events/legacy)', () {
      expect(SoleuxJsonResponse.maybeParse('OUT:0:ON'), isNull);
      expect(SoleuxJsonResponse.maybeParse('OK'), isNull);
      expect(
          SoleuxJsonResponse.maybeParse('Error : Function Disabled'), isNull);
    });

    test('returns null for malformed JSON instead of throwing', () {
      expect(SoleuxJsonResponse.maybeParse('J:not json'), isNull);
      expect(SoleuxJsonResponse.maybeParse('J:{"id":1}'), isNull);
      expect(SoleuxJsonResponse.maybeParse('{"id":1'), isNull);
    });

    test('parses plain Control API lines and ignores unknown fields', () {
      final response = SoleuxJsonResponse.maybeParse(
          '{"protocol":2,"id":7,"ok":true,"future_field":"x","result":{}}');
      expect(response, isNotNull);
      expect(response!.id, 7);
      expect(response.ok, isTrue);
    });

    test('still parses legacy J: lines for pre-Control-API devices', () {
      final response = SoleuxJsonResponse.maybeParse(
          'J:{"protocol":2,"id":7,"ok":true,"result":{}}');
      expect(response, isNotNull);
      expect(response!.id, 7);
      expect(response.ok, isTrue);
    });
  });

  group('SoleuxLineSplitter framing', () {
    test('splits CRLF-terminated lines', () {
      final splitter = SoleuxLineSplitter();
      final lines = splitter.add('J:{"id":1}\r\nJ:{"id":2}\r\n');
      expect(lines, hasLength(2));
      expect(lines[0], 'J:{"id":1}');
      expect(lines[1], 'J:{"id":2}');
      expect(splitter.hasPending, isFalse);
    });

    test('buffers a trailing partial line across chunks', () {
      final splitter = SoleuxLineSplitter();
      expect(splitter.add('J:{"id":'), isEmpty);
      expect(splitter.hasPending, isTrue);
      final lines = splitter.add('1,"action":"hello"}\r\n');
      expect(lines, singleLineBufferEquals('J:{"id":1,"action":"hello"}'));
      expect(splitter.hasPending, isFalse);
    });

    test('handles lone LF terminators', () {
      final splitter = SoleuxLineSplitter();
      final lines = splitter.add('OUT:0:ON\nIN:1:OFF\n');
      expect(lines, ['OUT:0:ON', 'IN:1:OFF']);
    });

    test('handles a multi-line burst split in the middle of a line', () {
      final splitter = SoleuxLineSplitter();
      final head = splitter.add('OUT:0:ON\r\nJ:{"id":1,"act');
      expect(head, ['OUT:0:ON']);
      final tail = splitter.add('ion":"hello"}\r\nGETENERGY:1:2:3:E\r\n');
      expect(tail, ['J:{"id":1,"action":"hello"}', 'GETENERGY:1:2:3:E']);
      expect(splitter.hasPending, isFalse);
    });
  });

  group('SoleuxEnergyParameter', () {
    test('indices and units match the doc table', () {
      expect(SoleuxEnergyParameter.voltage.index, 0);
      expect(SoleuxEnergyParameter.voltage.unit, 'V');
      expect(SoleuxEnergyParameter.energy.index, 5);
      expect(SoleuxEnergyParameter.energy.unit, 'kWh');
      expect(SoleuxEnergyParameter.powerFactor.index, 3);
    });
  });
}

// `hasLength` + equality helper for the single buffered line case.
Matcher singleLineBufferEquals(String expected) => predicate(
    (List<String> lines) => lines.length == 1 && lines.single == expected,
    'a single line equal to $expected');
