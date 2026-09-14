// lib/services/custom_color_store.dart
//
// App-wide persistence for the user's saved custom scenario background
// colors ("My colors"). Colors are stored as ARGB ints in
// shared_preferences so they survive app restarts and are offered as
// selectable swatches in the scenario editor, alongside the built-in
// presets. Only colors saved through the picker land here; presets and the
// "Default" choice stay built-in.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomColorStore extends ChangeNotifier {
  CustomColorStore._();

  /// App-wide shared instance used by the scenario editor.
  static CustomColorStore shared = CustomColorStore._();

  /// Creates an isolated store for tests (backed by the same persistence).
  @visibleForTesting
  static CustomColorStore forTesting() => CustomColorStore._();

  static const String _storageKey = 'custom_color_palette';
  static const int _maxColors = 12;

  SharedPreferences? _prefs;
  bool _loaded = false;
  final List<Color> _colors = [];

  /// The user's saved custom colors, in saved order (unmodifiable view).
  List<Color> get colors => List.unmodifiable(_colors);

  bool get loaded => _loaded;

  /// Maximum number of custom colors that can be saved.
  int get maxColors => _maxColors;

  bool contains(Color color) => _colors.contains(color);

  /// Loads the saved palette exactly once. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _colors
        ..clear()
        ..addAll([
          for (final raw in _prefs!.getStringList(_storageKey) ?? const [])
            Color(int.parse(raw)),
        ]);
    } catch (e, st) {
      debugPrint('CustomColorStore: loading palette failed: $e\n$st');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Saves [color] to the user palette. Returns false (and does not save)
  /// when the color is already present or the palette is full.
  Future<bool> add(Color color) async {
    await init();
    if (contains(color) || _colors.length >= _maxColors) return false;
    _colors.add(color);
    await _persist();
    return true;
  }

  /// Removes [color] from the user palette.
  Future<void> remove(Color color) async {
    await init();
    if (!_colors.remove(color)) return;
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs?.setStringList(
      _storageKey,
      [for (final c in _colors) '${c.toARGB32()}'],
    );
    notifyListeners();
  }
}