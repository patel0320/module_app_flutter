import 'package:flutter_test/flutter_test.dart';

import 'package:module_app_flutter/data/models/temperature_alert.dart';

void main() {
  group('TemperatureAlert', () {
    const alert = TemperatureAlert(
      id: 't1',
      moduleId: 'm3',
      minC: 10,
      maxC: 30,
    );

    test('is not triggered inside thresholds', () {
      expect(alert.isTriggered(22.0), isFalse);
    });

    test('is triggered above max', () {
      expect(alert.isTriggered(30.1), isTrue);
    });

    test('is triggered below min', () {
      expect(alert.isTriggered(9.9), isTrue);
    });

    test('is not triggered when disabled', () {
      const disabled = TemperatureAlert(
        id: 't2',
        moduleId: 'm3',
        minC: 10,
        maxC: 30,
        enabled: false,
      );
      expect(disabled.isTriggered(50.0), isFalse);
    });
  });
}
