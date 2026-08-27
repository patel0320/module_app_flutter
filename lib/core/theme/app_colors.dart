import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // High-contrast minimalist palette (black & white core, per the product brief).
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF111111);
  static const Color onDark = Color(0xFFFFFFFF);

  static const Color online = Color(0xFF00C853);
  static const Color offline = Color(0xFFD50000);
  static const Color warning = Color(0xFFFFB300);

  static const Color controlOn = Color(0xFF00E676);
  static const Color controlOff = Color(0xFF333333);
  static const Color controlDim = Color(0xFF00701A);

  // ---- Mint Frost "Command Deck" palette (Home screen) ----------------
  // Raw hex values copied from the reference stylesheet (styles.css).

  // Background gradient: linear-gradient(145deg, #02040a 0%, #07111f 52%, #050816 100%)
  static const Color deckBgDeep = Color(0xFF02040A);
  static const Color deckBgMid = Color(0xFF07111F);
  static const Color deckBgTop = Color(0xFF050816);

  // --text-main: #f8fbff
  static const Color deckTextMain = Color(0xFFF8FBFF);
  // --primary: #55f5b1 (mint)
  static const Color deckMint = Color(0xFF55F5B1);
  // Light-mode mint (readable on white).
  static const Color deckMintLight = Color(0xFF0E9F74);
  // --accent-blue: #66d9ff
  static const Color deckBlue = Color(0xFF66D9FF);
  // Light-mode blue.
  static const Color deckBlueLight = Color(0xFF0284C7);
  // --accent-violet: #9f7aea
  static const Color deckViolet = Color(0xFF9F7AEA);
  // Light-mode violet.
  static const Color deckVioletLight = Color(0xFF7C3AED);
  // Grey-tinted backdrop orb (replaces the blue aurora hint).
  static const Color deckGrey = Color(0xFF9CA3AF);
  // --danger-soft: rgba(239, 68, 68, 0.18) -> base red #ef4444
  static const Color deckDanger = Color(0xFFEF4444);

  // Connectivity / alert semantics for the Home dot + red banner.
  static const Color deckOnline = Color(0xFF00A651);
  static const Color deckOfflineRed = Color(0xFFD32F2F);

  // ---- Home screen inline glass/text accents --------------------------
  // Room bottom-sheet background (dark) and light.
  static const Color deckSheetDark = Color(0xFF0A0F1C);
  static const Color deckSheetLight = Color(0xFFFFFFFF);
  // Alert banner foreground (dark / light).
  static const Color deckAlertFgDark = Color(0xFFFF8A7A);
  static const Color deckAlertFgLight = Color(0xFFB3202E);
  // Run-button gradient + label + glow.
  static const Color deckRunStar = Color(0xFF55F5B1);
  static const Color deckRunEnd = Color(0xFF22C55E);
  static const Color deckRunGlow = Color(0x8055F5B1);
  static const Color deckRunLabel = Color(0xFF05261B);
  // Light-mode neutral text.
  static const Color deckTextLight = Color(0xFF111827);
}
