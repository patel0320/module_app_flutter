// lib/theme/app_theme.dart
//
// Centralized colors and ThemeData for the whole app (Material 3).
// Design language: minimalist, high-contrast, black & white, with a
// disciplined accent palette:
//   - green (#00A651) is reserved for "online" connectivity status only
//   - red   (#D32F2F) is reserved for "offline" / alert states only
// ON/OFF and active/inactive control states are communicated with
// fill-vs-outline contrast (solid black = active, outlined = inactive)
// rather than color, so they never collide with the online/offline meaning.
import 'package:flutter/material.dart';

/// App-wide flat color palette, exactly as specified in the design brief.
abstract class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF333333);
  static const Color online = Color(0xFF00A651);
  static const Color offlineAlert = Color(0xFFD32F2F);

  // Supporting neutrals for dark mode surfaces / subtle fills.
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceAlt = Color(0xFF242424);
  static const Color lightSurfaceAlt = Color(0xFFF3F3F3);
}

/// Global theme-mode holder. Kept as a plain [ValueNotifier] (no
/// third-party state management) so the Settings screen can flip
/// Light / Dark / System instantly from anywhere in the widget tree.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

abstract class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final Color onSurface = isLight ? AppColors.black : AppColors.white;
    final Color background = isLight ? AppColors.white : AppColors.black;
    final Color surface = isLight ? AppColors.white : AppColors.darkSurface;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkGray,
      brightness: brightness,
    ).copyWith(
      primary: onSurface,
      onPrimary: background,
      secondary: AppColors.darkGray,
      onSecondary: AppColors.white,
      surface: surface,
      onSurface: onSurface,
      error: AppColors.offlineAlert,
      onError: AppColors.white,
      outline: onSurface.withOpacity(0.24),
    );

    final ThemeData base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: colorScheme);
    final TextTheme textTheme = base.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 22),
        iconTheme: IconThemeData(color: onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: onSurface.withOpacity(0.1),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: onSurface,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: onSurface.withOpacity(states.contains(WidgetState.selected) ? 1 : 0.5),
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: onSurface.withOpacity(0.12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        minVerticalPadding: 12,
      ),
      dividerTheme: DividerThemeData(color: onSurface.withOpacity(0.1), space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: onSurface,
          foregroundColor: background,
          disabledBackgroundColor: onSurface.withOpacity(0.3),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: onSurface,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.online : (isLight ? AppColors.white : AppColors.darkGray),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.online.withOpacity(0.4) : onSurface.withOpacity(0.15),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: onSurface,
        inactiveTrackColor: onSurface.withOpacity(0.15),
        thumbColor: onSurface,
        overlayColor: onSurface.withOpacity(0.1),
        valueIndicatorColor: onSurface,
        valueIndicatorTextStyle: TextStyle(color: background, fontWeight: FontWeight.w700),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onSurface : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(background),
        side: BorderSide(color: onSurface, width: 1.4),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(onSurface),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.lightSurfaceAlt : AppColors.darkSurfaceAlt,
        selectedColor: onSurface,
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: background, fontWeight: FontWeight.w600),
        side: BorderSide(color: onSurface.withOpacity(0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: onSurface,
          selectedForegroundColor: background,
          selectedBackgroundColor: onSurface,
          side: BorderSide(color: onSurface, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightSurfaceAlt : AppColors.darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: onSurface, width: 1.6),
        ),
        labelStyle: TextStyle(color: onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: background, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: onSurface,
        foregroundColor: background,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: onSurface),
    );
  }
}

/// Standard spacing constants used across every screen for a consistent
/// rhythm: 16dp outer padding, 12dp between cards.
abstract class AppSpacing {
  static const double outerPadding = 16;
  static const double betweenCards = 12;
}
