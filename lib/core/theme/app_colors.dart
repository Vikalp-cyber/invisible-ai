import 'package:flutter/material.dart';

/// ── App Color Palette ──────────────────────────────────────────────────────
/// Dark futuristic theme with electric cyan and neon violet accents.
/// All colors are defined here to ensure visual consistency across the app.
class AppColors {
  AppColors._();

  // ── Backgrounds ────────────────────────────────────────────────────────────
  /// Deepest background — the base layer of the floating window.
  static const Color backgroundDark = Color(0xFF0A0E1A);

  /// Slightly lighter variant for layered depth.
  static const Color backgroundMedium = Color(0xFF0F1328);

  /// Surface color for cards and containers.
  static const Color surface = Color(0xFF141832);

  // ── Primary Accent — Electric Cyan ─────────────────────────────────────────
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryLight = Color(0xFF6EFFFF);
  static const Color primaryDark = Color(0xFF00B2CC);

  // ── Secondary Accent — Neon Violet ─────────────────────────────────────────
  static const Color secondary = Color(0xFF7C4DFF);
  static const Color secondaryLight = Color(0xFFB47CFF);
  static const Color secondaryDark = Color(0xFF3F1DCB);

  // ── Text Colors ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFB0B3C5);
  static const Color textMuted = Color(0xFF6B6F85);
  static const Color textOnPrimary = Color(0xFF001517);

  // ── Glass Effect Colors ────────────────────────────────────────────────────
  /// White overlay for glass surfaces.
  static const Color glassWhite = Color(0x0FFFFFFF); // ~6% white
  static const Color glassBorder = Color(0x2600E5FF); // ~15% cyan

  /// Stronger glass for focused/hovered states.
  static const Color glassWhiteHover = Color(0x1AFFFFFF); // ~10% white

  // ── Status Colors ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB40);
  static const Color error = Color(0xFFFF5252);

  // ── Gradients ──────────────────────────────────────────────────────────────
  /// Primary accent gradient for user message bubbles.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF00B8D4)],
  );

  /// Secondary accent gradient for highlights.
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, Color(0xFF536DFE)],
  );

  /// Subtle glass gradient for backgrounds.
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x0DFFFFFF), // 5% white
      Color(0x05FFFFFF), // 2% white
    ],
  );

  /// Title bar gradient — subtle depth.
  static const LinearGradient titleBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x1A00E5FF), // 10% cyan
      Color(0x00000000), // transparent
    ],
  );

  // ── Shadows ────────────────────────────────────────────────────────────────
  /// Window drop shadow.
  static List<BoxShadow> windowShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: primary.withValues(alpha: 0.08),
      blurRadius: 48,
      offset: const Offset(0, 4),
    ),
  ];

  /// Subtle glow shadow for interactive elements.
  static List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 2),
    ),
  ];
}
