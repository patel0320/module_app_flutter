import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soleux_device_manager/services/custom_color_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts empty and persists added colors across instances', () async {
    const color = Color(0xFF28455F);
    final a = CustomColorStore.forTesting();
    await a.init();
    expect(a.colors, isEmpty);

    expect(await a.add(color), isTrue);
    expect(a.colors, [color]);

    final b = CustomColorStore.forTesting();
    await b.init();
    expect(b.colors, [color]);
  });

  test('does not save duplicates', () async {
    const color = Color(0xFF28455F);
    final store = CustomColorStore.forTesting();
    await store.init();
    expect(await store.add(color), isTrue);
    expect(await store.add(color), isFalse);
    expect(store.colors, hasLength(1));
  });

  test('remove deletes a saved color', () async {
    const color = Color(0xFF28455F);
    final store = CustomColorStore.forTesting();
    await store.init();
    await store.add(color);
    await store.remove(color);
    expect(store.colors, isEmpty);
  });

  test('respects the maximum palette size', () async {
    final store = CustomColorStore.forTesting();
    await store.init();
    for (int i = 0; i < store.maxColors; i++) {
      expect(await store.add(Color(0xFF000000 + i)), isTrue,
          reason: 'add #$i should succeed');
    }
    expect(await store.add(const Color(0xFF123456)), isFalse);
    expect(store.colors, hasLength(store.maxColors));
  });

  test('presets are not saved through the store on their own', () async {
    final store = CustomColorStore.forTesting();
    await store.init();
    expect(store.colors, isEmpty);
  });
}