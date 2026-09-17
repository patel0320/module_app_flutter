// Tests for the Soleux Control API device event codec
// (doc/Soleux_Control_API_Command_Specification_v0.6.md §"Device events").
// Events are unsolicited JSON envelopes carrying `event` + `data` and no
// `ok`/`result`:
//
//   {"protocol":3,"event":"output_state_changed","subscription_id":"sub-7",
//    "data":{"channel":0,"previous_state":false,"state":true,"pending":false,
//            "source":"windows-app","revision":312,
//            "timestamp":"2026-08-31T10:20:30+00:00"}}
import 'package:flutter_test/flutter_test.dart';
import 'package:soleux_device_manager/core/soleux/soleux_device_event.dart';

void main() {
  group('SoleuxDeviceEvent.maybeParse', () {
    test('parses the documented output_state_changed envelope', () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"protocol":3,"event":"output_state_changed",'
          '"subscription_id":"sub-7",'
          '"data":{"channel":0,"previous_state":false,"state":true,'
          '"pending":false,"source":"windows-app","revision":312,'
          '"timestamp":"2026-08-31T10:20:30+00:00"}}');
      expect(event, isNotNull);
      expect(event!.protocol, 3);
      expect(event.type, SoleuxDeviceEventType.outputStateChanged);
      expect(event.rawEvent, 'output_state_changed');
      expect(event.subscriptionId, 'sub-7');
      expect(event.channel, 0);
      expect(event.previousState, isFalse);
      expect(event.state, isTrue);
      expect(event.pending, isFalse);
      expect(event.source, 'windows-app');
      expect(event.revision, 312);
      expect(event.timestamp, DateTime.parse('2026-08-31T10:20:30+00:00'));
    });

    test('recognises every catalogued event type', () {
      const samples = <String, SoleuxDeviceEventType>{
        'output_state_changed': SoleuxDeviceEventType.outputStateChanged,
        'output_level_changed': SoleuxDeviceEventType.outputLevelChanged,
        'pwm_state_changed': SoleuxDeviceEventType.pwmStateChanged,
        'input_state_changed': SoleuxDeviceEventType.inputStateChanged,
        'mapping_changed': SoleuxDeviceEventType.mappingChanged,
        'temperature_changed': SoleuxDeviceEventType.temperatureChanged,
        'system_status': SoleuxDeviceEventType.systemStatus,
        'energy_changed': SoleuxDeviceEventType.energyChanged,
        'schedule_executed': SoleuxDeviceEventType.scheduleExecuted,
        'automation_executed': SoleuxDeviceEventType.automationExecuted,
        'sequence_state_changed': SoleuxDeviceEventType.sequenceStateChanged,
        'operation_progress': SoleuxDeviceEventType.operationProgress,
        'device_fault': SoleuxDeviceEventType.deviceFault,
        'configuration_changed': SoleuxDeviceEventType.configurationChanged,
        'device_rebooting': SoleuxDeviceEventType.deviceRebooting,
      };
      for (final entry in samples.entries) {
        final event =
            SoleuxDeviceEvent.maybeParse('{"event":"${entry.key}","data":{}}');
        expect(event, isNotNull, reason: entry.key);
        expect(event!.type, entry.value);
      }
    });

    test('returns null for command responses and legacy lines', () {
      expect(
          SoleuxDeviceEvent.maybeParse(
              '{"protocol":2,"id":42,"ok":true,"result":{}}'),
          isNull);
      expect(SoleuxDeviceEvent.maybeParse('OUT:0:ON'), isNull);
      expect(SoleuxDeviceEvent.maybeParse('OK'), isNull);
      expect(SoleuxDeviceEvent.maybeParse(''), isNull);
      expect(SoleuxDeviceEvent.maybeParse('not json'), isNull);
    });

    test('tolerates a malformed line without throwing', () {
      expect(SoleuxDeviceEvent.maybeParse('{"event":'), isNull);
      expect(SoleuxDeviceEvent.maybeParse('[1,2,3]'), isNull);
    });

    test('unknown events surface as unknown with the raw event string', () {
      final event =
          SoleuxDeviceEvent.maybeParse('{"event":"brand_new_event","data":{}}');
      expect(event, isNotNull);
      expect(event!.type, SoleuxDeviceEventType.unknown);
      expect(event.rawEvent, 'brand_new_event');
    });

    test('missing data degrades to an empty map', () {
      final event =
          SoleuxDeviceEvent.maybeParse('{"event":"temperature_changed"}');
      expect(event, isNotNull);
      expect(event!.data, isEmpty);
      expect(event.timestamp, isNull);
      expect(event.revision, isNull);
    });
  });

  group('typed data fields per event', () {
    test('output_level_changed exposes requested/actual levels', () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"event":"output_level_changed","data":{"channel":2,'
          '"requested_level":80,"actual_level":40,"transitioning":true,'
          '"source":"app","revision":5,'
          '"timestamp":"2026-08-31T10:20:31+00:00"}}');
      expect(event!.channel, 2);
      expect(event.requestedLevel, 80.0);
      expect(event.actualLevel, 40.0);
      expect(event.transitioning, isTrue);
    });

    test('input_state_changed exposes kind + state', () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"event":"input_state_changed","data":{"kind":"physical","channel":1,'
          '"previous_state":false,"state":true,"source":"input","revision":9,'
          '"timestamp":"2026-08-31T10:20:32+00:00"}}');
      expect(event!.kind, 'physical');
      expect(event.channel, 1);
      expect(event.state, isTrue);
    });

    test('pwm_state_changed exposes set/actual PWM + direction + confirmed', () {
      // Protocol-2 broadcast shape (Soleux-Mobile-TCP-Protocol.md): the payload
      // under `result` with id null / ok true.
      final event = SoleuxDeviceEvent.maybeParse('{"result":{"direction":"UP",'
          '"confirmed":true,"actual_pwm":83,"set_pwm":100,"channel":3,'
          '"revision":1789633582100},"ok":true,"protocol":2,"id":null,'
          '"event":"pwm_state_changed"}');
      expect(event, isNotNull);
      expect(event!.protocol, 2);
      expect(event.type, SoleuxDeviceEventType.pwmStateChanged);
      expect(event.rawEvent, 'pwm_state_changed');
      expect(event.channel, 3);
      expect(event.setPwm, 100.0);
      expect(event.actualPwm, 83.0);
      expect(event.direction, 'UP');
      expect(event.confirmed, isTrue);
      expect(event.revision, 1789633582100);
    });

    test('protocol-2 broadcast envelope (result payload) is parsed', () {
      // Soleux-Mobile-TCP-Protocol.md broadcast shape: id null, ok true, and
      // the typed payload under `result` instead of `data`.
      final event = SoleuxDeviceEvent.maybeParse(
          '{"protocol":2,"id":null,"ok":true,"event":"input_state_changed",'
          '"result":{"channel":2,"state":true,"revision":1789531200000}}');
      expect(event, isNotNull);
      expect(event!.protocol, 2);
      expect(event.type, SoleuxDeviceEventType.inputStateChanged);
      expect(event.rawEvent, 'input_state_changed');
      expect(event.channel, 2);
      expect(event.state, isTrue);
      expect(event.revision, 1789531200000);

      final output = SoleuxDeviceEvent.maybeParse(
          '{"protocol":2,"id":null,"ok":true,"event":"output_state_changed",'
          '"result":{"channel":2,"state":false,"revision":1789531200123}}');
      expect(output, isNotNull);
      expect(output!.type, SoleuxDeviceEventType.outputStateChanged);
      expect(output.channel, 2);
      expect(output.state, isFalse);
      expect(output.revision, 1789531200123);
    });

    test('system_status exposes the same shape as a get_device_state result',
        () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"protocol":2,"id":null,"ok":true,"event":"system_status",'
          '"result":{"revision":1789531205000,'
          '"captured_at":"2026-09-16T12:00:05.123456",'
          '"sensors":[{"sensor_id":"external","value_c":25.4},'
          '{"sensor_id":"cpu","value_c":47.0}],'
          '"system":{"time":"2026/09/16 12:00:05","uptime":"2 hours",'
          '"external_temp_c":25.4,"cpu_temp_c":47.0,'
          '"free_memory_mb":184,"total_memory_mb":512,"used_memory_mb":328,'
          '"memory_usage_percent":64.06,"cpu_usage_percent":12.5},'
          '"network":{"lan_ip":"192.168.1.50","wifi_ip":"192.168.1.51",'
          '"wifi_ssid":"Office WiFi"}}}');
      expect(event, isNotNull);
      expect(event!.type, SoleuxDeviceEventType.systemStatus);
      expect(event.revision, 1789531205000);
      expect(event.capturedAt, '2026-09-16T12:00:05.123456');
      expect(event.sensors, hasLength(2));
      expect(event.system, isNotNull);
      expect(event.system!['cpu_usage_percent'], 12.5);
      expect(event.network, isNotNull);
      expect(event.network!['lan_ip'], '192.168.1.50');
      expect(event.network!['wifi_ssid'], 'Office WiFi');
    });

    test('mapping_changed exposes input/output/behavior/legacy_code', () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"event":"mapping_changed","data":{"input":0,"output":3,'
          '"behavior":1,"legacy_code":2,"revision":11,'
          '"timestamp":"2026-08-31T10:20:33+00:00"}}');
      expect(event!.mappingInput, 0);
      expect(event.mappingOutput, 3);
      expect(event.behavior, 1);
      expect(event.legacyCode, 2);
      expect(event.revision, 11);
    });

    test('temperature_changed exposes sensor + value_c + status', () {
      final event = SoleuxDeviceEvent.maybeParse(
          '{"event":"temperature_changed","data":{"sensor_id":0,"value_c":27.4,'
          '"status":"ok","timestamp":"2026-08-31T10:20:34+00:00"}}');
      expect(event!.sensorId, 0);
      expect(event.valueC, 27.4);
      expect(event.readingStatus, 'ok');
    });

    test('schedule/automation executed expose ids, results and success', () {
      final schedule = SoleuxDeviceEvent.maybeParse(
          '{"event":"schedule_executed","data":{"schedule_id":4,'
          '"results":[{"ok":true}],"success":true,'
          '"timestamp":"2026-08-31T10:20:35+00:00"}}');
      expect(schedule!.scheduleId, 4);
      expect(schedule.success, isTrue);
      expect(schedule.results, isNotEmpty);

      final automation = SoleuxDeviceEvent.maybeParse(
          '{"event":"automation_executed","data":{"automation_id":7,'
          '"trigger":"output_state_changed","results":[{"ok":false}],'
          '"success":false,"timestamp":"2026-08-31T10:20:36+00:00"}}');
      expect(automation!.automationId, 7);
      expect(automation.trigger, 'output_state_changed');
      expect(automation.success, isFalse);
    });

    test('sequence/operation/reboot/configuration/fault expose their fields',
        () {
      final sequence = SoleuxDeviceEvent.maybeParse(
          '{"event":"sequence_state_changed","data":{"sequence_id":1,'
          '"operation_id":9,"state":"running","step":2,"loop":1,'
          '"timestamp":"2026-08-31T10:20:37+00:00"}}');
      expect(sequence!.sequenceId, 1);
      expect(sequence.operationId, 9);
      expect(sequence.step, 2);
      expect(sequence.loop, 1);

      final progress = SoleuxDeviceEvent.maybeParse(
          '{"event":"operation_progress","data":{"operation_id":"op-9",'
          '"kind":"restart","stage":"waiting_off","progress_percent":45,'
          '"message":"turning off","timestamp":"2026-08-31T10:20:38+00:00"}}');
      expect(progress!.kind, 'restart');
      expect(progress.stage, 'waiting_off');
      expect(progress.progressPercent, 45.0);
      expect(progress.message, 'turning off');

      final fault = SoleuxDeviceEvent.maybeParse(
          '{"event":"device_fault","data":{"fault_id":3,"severity":"critical",'
          '"code":"overcurrent","message":"current too high","active":true,'
          '"timestamp":"2026-08-31T10:20:39+00:00"}}');
      expect(fault!.faultId, 3);
      expect(fault.severity, 'critical');
      expect(fault.code, 'overcurrent');
      expect(fault.active, isTrue);

      final config = SoleuxDeviceEvent.maybeParse(
          '{"event":"configuration_changed","data":{"section":"lan",'
          '"revision":21,"source":"web","restart_required":true,'
          '"timestamp":"2026-08-31T10:20:40+00:00"}}');
      expect(config!.section, 'lan');
      expect(config.restartRequired, isTrue);

      final reboot = SoleuxDeviceEvent.maybeParse(
          '{"event":"device_rebooting","data":{"reason":"firmware_update",'
          '"reboot_in_ms":5000,"timestamp":"2026-08-31T10:20:41+00:00"}}');
      expect(reboot!.reason, 'firmware_update');
      expect(reboot.rebootInMs, 5000);
    });
  });
}
