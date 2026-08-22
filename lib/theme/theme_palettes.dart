// lib/theme/theme_palettes.dart
//
// Multi-theme palette system ported from the reference dashboard
// (E:\work\smart-home-dashboard\public\styles.css).  The token vocabulary is
// identical to the flagship "Neo-Aurora Command Deck" (`:root` / `body.theme-aurora`):
//
//   --bg-color, --panel-bg, --panel-border, --text-main, --text-muted,
//   --primary, --primary-glow, --accent-blue, --accent-violet
//
// plus the small set of extra semantic colors the Home screen needs
// (online / offline / danger / run-button gradient), which stay green/red so
// the meanings never collide across themes.  Each [HomeThemeId] maps to a
// [HomePalette]; dark is authoritative for each (copied hex-verbatim), light
// keeps the same glass language with brightness-inverted neutrals.
import 'package:flutter/material.dart';

/// Themes available in the Home-screen theme switcher, matching the
/// dashboard's theme selector.
enum HomeThemeId {
  aurora,
  cyberpunk,
  nordic,
  retrowave,
  terminal,
  stealth,
}

/// Currently selected Home theme. Kept as a plain [ValueNotifier] so the
/// theme switcher can flip palettes from anywhere without a new package.
final ValueNotifier<HomeThemeId> homeThemeIdNotifier =
    ValueNotifier<HomeThemeId>(HomeThemeId.aurora);

@immutable
class HomePalette {
  const HomePalette({
    required this.id,
    required this.name,
    required this.icon,
    required this.glass,
    required this.radiusLg,
    required this.radiusMd,
    required this.radiusSm,
    // dark
    required this.backgroundGradient,
    required this.panelGradient,
    required this.panelBorder,
    required this.text,
    required this.textMuted,
    required this.primary,
    required this.primaryGlow,
    required this.accentBlue,
    required this.accentViolet,
    required this.hairline,
    required this.sectionLabel,
    required this.orbColors,
    // semantics (kept green/red across themes)
    required this.danger,
    required this.online,
    required this.offline,
    required this.runStart,
    required this.runEnd,
    required this.runLabel,
    // light
    required this.lightBackgroundGradient,
    required this.lightPrimary,
    required this.lightBlue,
    required this.lightViolet,
    required this.lightText,
    required this.lightTextMuted,
    required this.lightPanelBorder,
  });

  final HomeThemeId id;
  final String name;
  final IconData icon;

  /// Whether the theme uses frosted glass + soft shadows (`--blur`) or flat
  /// panels (OLED stealth / terminal / nordic).
  final bool glass;
  final double radiusLg;
  final double radiusMd;
  final double radiusSm;

  // Dark tokens (verbatim from the reference stylesheet).
  final LinearGradient backgroundGradient;
  final LinearGradient panelGradient;
  final Color panelBorder;
  final Color text;
  final Color textMuted;
  final Color primary;
  final Color primaryGlow;
  final Color accentBlue;
  final Color accentViolet;
  final Color hairline;
  final Color sectionLabel;
  final List<Color> orbColors;

  // Semantic colors.
  final Color danger;
  final Color online;
  final Color offline;
  final Color runStart;
  final Color runEnd;
  final Color runLabel;

  // Light tokens (brightness-inverted neutrals, same primary/accent language).
  final LinearGradient lightBackgroundGradient;
  final Color lightPrimary;
  final Color lightBlue;
  final Color lightViolet;
  final Color lightText;
  final Color lightTextMuted;
  final Color lightPanelBorder;
}

/// Registry of every supported palette, in the order shown in the dashboard
/// theme selector.
abstract final class HomeThemePalettes {
  static const List<HomePalette> all = _all;
  static const List<HomePalette> _all = [
    _aurora,
    _cyberpunk,
    _nordic,
    _retrowave,
    _terminal,
    _stealth,
  ];

  static HomePalette byId(HomeThemeId id) =>
      all.firstWhere((p) => p.id == id);

  // ---------------------------------------------------------------------------
  // 1. NEO-AURORA COMMAND DECK (flagship) — styles.css :root / theme-aurora
  // ---------------------------------------------------------------------------
  static const HomePalette _aurora = HomePalette(
    id: HomeThemeId.aurora,
    name: 'Neo-Aurora',
    icon: Icons.blur_on,
    glass: true,
    radiusLg: 28,
    radiusMd: 18,
    radiusSm: 12,
    // background: linear-gradient(145deg,#02040a 0%,#07111f 52%,#050816 100%)
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF02040A), Color(0xFF07111F), Color(0xFF050816)],
      stops: [0, 0.52, 1],
    ),
    // widget bg: linear-gradient(145deg, rgba(255,255,255,.075),
    //           rgba(255,255,255,.028) 42%, rgba(4,10,22,.45))
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x14FFFFFF), Color(0x070A0F1F)],
      stops: [0, 1],
    ),
    // --panel-border: rgba(170,214,255,0.14)
    panelBorder: Color(0x24AAD6FF),
    // --text-main: #f8fbff
    text: Color(0xFFF8FBFF),
    // --text-muted: rgba(218,232,255,0.58)
    textMuted: Color(0x94F8FBFF),
    // --primary: #55f5b1 (mint)
    primary: Color(0xFF55F5B1),
    // --primary-glow: rgba(85,245,177,0.28)
    primaryGlow: Color(0x4755F5B1),
    // --accent-blue: #66d9ff
    accentBlue: Color(0xFF66D9FF),
    // --accent-violet: #9f7aea
    accentViolet: Color(0xFF9F7AEA),
    // widget::after top hairline highlight
    hairline: Color(0x33FFFFFF),
    // widget-header h3: rgba(233,244,255,0.62)
    sectionLabel: Color(0x9EE9F4FF),
    // orbs: orb-1 #00ffa3, orb-2 #00b7ff, orb-3 #7c3aed
    orbColors: [Color(0xFF00FFA3), Color(0xFF00B7FF), Color(0xFF7C3AED)],
    danger: Color(0xFFEF4444),
    online: Color(0xFF00A651),
    offline: Color(0xFFD32F2F),
    runStart: Color(0xFF55F5B1),
    runEnd: Color(0xFF22C55E),
    runLabel: Color(0xFF05261B),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6FAFF), Color(0xFFEEF4FF), Color(0xFFF4F0FF)],
    ),
    lightPrimary: Color(0xFF0E9F74),
    lightBlue: Color(0xFF0284C7),
    lightViolet: Color(0xFF7C3AED),
    lightText: Color(0xFF111827),
    lightTextMuted: Color(0x99111827),
    lightPanelBorder: Color(0x1F111827),
  );

  // ---------------------------------------------------------------------------
  // 2. CYBERPUNK TACTICAL HUD — styles.css theme-cyberpunk
  // ---------------------------------------------------------------------------
  static const HomePalette _cyberpunk = HomePalette(
    id: HomeThemeId.cyberpunk,
    name: 'Cyberpunk',
    icon: Icons.emoji_objects_outlined,
    glass: false,
    radiusLg: 0,
    radiusMd: 0,
    radiusSm: 0,
    // background: linear-gradient(145deg,#050507 0%,#100d14 100%) over #08080a
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF050507), Color(0xFF100D14)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x1AFFFFFF), Color(0xE6100F13)],
    ),
    // --panel-border: rgba(255,120,0,0.28)
    panelBorder: Color(0x47FF7800),
    // --text-main: #ffd1a4
    text: Color(0xFFFFD1A4),
    // --text-muted: rgba(255,209,164,0.5)
    textMuted: Color(0x80FFD1A4),
    // --primary: #ff7300
    primary: Color(0xFFFF7300),
    // --primary-glow: rgba(255,115,0,0.35)
    primaryGlow: Color(0x59FF7300),
    // --accent-blue: #00e5ff
    accentBlue: Color(0xFF00E5FF),
    // --accent-violet: #ff3300
    accentViolet: Color(0xFFFF3300),
    hairline: Color(0x66FF7800),
    sectionLabel: Color(0xB3FFD1A4),
    orbColors: [Color(0xFFFF3300), Color(0xFFFF7300), Color(0xFF4A0000)],
    danger: Color(0xFFFF3300),
    online: Color(0xFF37F39B),
    offline: Color(0xFFFF3B30),
    runStart: Color(0xFFFF7300),
    runEnd: Color(0xFFFF3300),
    runLabel: Color(0xFF2B1200),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFBF7F3), Color(0xFFF5EDE4)],
    ),
    lightPrimary: Color(0xFFC0561B),
    lightBlue: Color(0xFF0091D6),
    lightViolet: Color(0xFFE02A6A),
    lightText: Color(0xFF221510),
    lightTextMuted: Color(0x99221510),
    lightPanelBorder: Color(0x1FC0561B),
  );

  // ---------------------------------------------------------------------------
  // 3. COZY NORDIC DARK — styles.css theme-nordic
  // ---------------------------------------------------------------------------
  static const HomePalette _nordic = HomePalette(
    id: HomeThemeId.nordic,
    name: 'Nordic',
    icon: Icons.ac_unit,
    glass: false,
    radiusLg: 20,
    radiusMd: 14,
    radiusSm: 8,
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF20262C), Color(0xFF181C20)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xEF1E242A), Color(0xEF262D34)],
    ),
    // --panel-border: rgba(255,255,255,0.05)
    panelBorder: Color(0x0DFFFFFF),
    // --text-main: #eceff4
    text: Color(0xFFECEFF4),
    // --text-muted: rgba(180,190,202,0.55)
    textMuted: Color(0x8CB4BECA),
    // --primary: #8fbcbb
    primary: Color(0xFF8FBCBB),
    // --primary-glow: rgba(143,188,187,0.2)
    primaryGlow: Color(0x338FBCBB),
    // --accent-blue: #a3be8c
    accentBlue: Color(0xFFA3BE8C),
    // --accent-violet: #b48ead
    accentViolet: Color(0xFFB48EAD),
    hairline: Color(0x1FFFFFFF),
    sectionLabel: Color(0x8FECEFF4),
    orbColors: [Color(0xFF8FBCBB), Color(0xFFA3BE8C), Color(0xFFB48EAD)],
    danger: Color(0xFFBF616A),
    online: Color(0xFF8FBCBB),
    offline: Color(0xFFBF616A),
    runStart: Color(0xFF8FBCBB),
    runEnd: Color(0xFFA3BE8C),
    runLabel: Color(0xFF0C1418),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF5F7F6), Color(0xFFEAEFEB)],
    ),
    lightPrimary: Color(0xFF4C7E7C),
    lightBlue: Color(0xFF6A8F5E),
    lightViolet: Color(0xFF9773A5),
    lightText: Color(0xFF2A2E33),
    lightTextMuted: Color(0x992A2E33),
    lightPanelBorder: Color(0x1F2A2E33),
  );

  // ---------------------------------------------------------------------------
  // 4. RETROWAVE LASER SYNTH — styles.css theme-retrowave
  // ---------------------------------------------------------------------------
  static const HomePalette _retrowave = HomePalette(
    id: HomeThemeId.retrowave,
    name: 'Retrowave',
    icon: Icons.gradient,
    glass: true,
    radiusLg: 16,
    radiusMd: 10,
    radiusSm: 6,
    // background: linear-gradient(180deg,#050209 0%,#120520 100%)
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF050209), Color(0xFF120520)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xB80E0418), Color(0xA013071E)],
    ),
    // --panel-border: rgba(255,0,127,0.25)
    panelBorder: Color(0x40FF007F),
    // --text-main: #ffedf6
    text: Color(0xFFFFEDF6),
    // --text-muted: rgba(255,185,222,0.52)
    textMuted: Color(0x85FFB9DE),
    // --primary: #ff007f
    primary: Color(0xFFFF007F),
    // --primary-glow: rgba(255,0,127,0.36)
    primaryGlow: Color(0x5CFF007F),
    // --accent-blue: #00f0ff
    accentBlue: Color(0xFF00F0FF),
    // --accent-violet: #bd00ff
    accentViolet: Color(0xFFBD00FF),
    hairline: Color(0x66FF007F),
    sectionLabel: Color(0xB8FFEDF6),
    orbColors: [Color(0xFFFF007F), Color(0xFFBD00FF), Color(0xFF00F0FF)],
    danger: Color(0xFFFF3366),
    online: Color(0xFF00F0FF),
    offline: Color(0xFFFF3366),
    runStart: Color(0xFFFF007F),
    runEnd: Color(0xFFBD00FF),
    runLabel: Color(0xFF2A0016),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFDF6FE), Color(0xFFF8EAFE)],
    ),
    lightPrimary: Color(0xFFD6007B),
    lightBlue: Color(0xFF148FB0),
    lightViolet: Color(0xFFA200E0),
    lightText: Color(0xFF2A0B2E),
    lightTextMuted: Color(0x992A0B2E),
    lightPanelBorder: Color(0x1FD6007B),
  );

  // ---------------------------------------------------------------------------
  // 5. TERMINAL CLASSIC — styles.css theme-terminal
  // ---------------------------------------------------------------------------
  static const HomePalette _terminal = HomePalette(
    id: HomeThemeId.terminal,
    name: 'Terminal',
    icon: Icons.terminal,
    glass: false,
    radiusLg: 4,
    radiusMd: 2,
    radiusSm: 0,
    // background: #050e05 (CRT scanlines omitted in-app)
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF050E05), Color(0xFF0A1A0C)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xD9051208), Color(0xD90A1F10)],
    ),
    // --panel-border: rgba(0,255,68,0.25)
    panelBorder: Color(0x4000FF44),
    // --text-main: #33ff33
    text: Color(0xFF33FF33),
    // --text-muted: rgba(51,255,51,0.5)
    textMuted: Color(0x8033FF33),
    // --primary: #00ff44
    primary: Color(0xFF00FF44),
    // --primary-glow: rgba(0,255,68,0.3)
    primaryGlow: Color(0x4D00FF44),
    // --accent-blue: #00ff88
    accentBlue: Color(0xFF00FF88),
    // --accent-violet: #adff2f
    accentViolet: Color(0xFFADFF2F),
    hairline: Color(0x4000FF44),
    sectionLabel: Color(0x8C33FF33),
    orbColors: [Color(0xFF00FF44), Color(0xFF00FF88), Color(0xFFADFF2F)],
    danger: Color(0xFFFF4500),
    online: Color(0xFF00FF44),
    offline: Color(0xFFFF4500),
    runStart: Color(0xFF00FF44),
    runEnd: Color(0xFF00FF88),
    runLabel: Color(0xFF001A08),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF2F7F3), Color(0xFFE6F2E8)],
    ),
    lightPrimary: Color(0xFF007A30),
    lightBlue: Color(0xFF008F5E),
    lightViolet: Color(0xFF4C7A2E),
    lightText: Color(0xFF0A1A0C),
    lightTextMuted: Color(0x990A1A0C),
    lightPanelBorder: Color(0x1F007A30),
  );

  // ---------------------------------------------------------------------------
  // 6. OLED STEALTH — styles.css theme-stealth
  // ---------------------------------------------------------------------------
  static const HomePalette _stealth = HomePalette(
    id: HomeThemeId.stealth,
    name: 'OLED Stealth',
    icon: Icons.dark_mode_outlined,
    glass: false,
    radiusLg: 14,
    radiusMd: 8,
    radiusSm: 4,
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF000000), Color(0xFF0A0A0A)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF0000000), Color(0xF0060606)],
    ),
    // --panel-border: rgba(255,255,255,0.1)
    panelBorder: Color(0x1AFFFFFF),
    // --text-main: #f3f4f6
    text: Color(0xFFF3F4F6),
    // --text-muted: #6b7280
    textMuted: Color(0xFF6B7280),
    // --primary: #9ca3af
    primary: Color(0xFF9CA3AF),
    // --primary-glow: rgba(255,255,255,0.05)
    primaryGlow: Color(0x0DFFFFFF),
    // --accent-blue: #4b5563
    accentBlue: Color(0xFF4B5563),
    // --accent-violet: #374151
    accentViolet: Color(0xFF374151),
    hairline: Color(0x16FFFFFF),
    sectionLabel: Color(0x99F3F4F6),
    orbColors: [Color(0xFF374151), Color(0xFF4B5563), Color(0xFF1F2937)],
    danger: Color(0xFFD32F2F),
    online: Color(0xFF9CA3AF),
    offline: Color(0xFFD32F2F),
    runStart: Color(0xFF4B5563),
    runEnd: Color(0xFF374151),
    runLabel: Color(0xFFFFFFFF),
    lightBackgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFAFAFA), Color(0xFFF2F2F2)],
    ),
    lightPrimary: Color(0xFF4B5563),
    lightBlue: Color(0xFF6B7280),
    lightViolet: Color(0xFF52525B),
    lightText: Color(0xFF111827),
    lightTextMuted: Color(0x99111827),
    lightPanelBorder: Color(0x1F111827),
  );
}
