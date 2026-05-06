import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ── App Theme ──────────────────────────────────────────────────────────────
/// Provides the dark futuristic ThemeData used throughout the application.
/// Uses system-safe typography to avoid runtime asset-manifest dependency.
class AppTheme {
  AppTheme._();

  /// The primary dark theme for the floating AI assistant.
  static ThemeData get darkTheme {
    // Base text theme using a local/system font so theme initialization works
    // even when AssetManifest.bin is unavailable (e.g. launching exe directly).
    final textTheme = ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',

      // ── Color Scheme ─────────────────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textPrimary,
      ),

      // ── Scaffold ─────────────────────────────────────────────────────────
      scaffoldBackgroundColor: Colors.transparent,

      // ── Text Theme ───────────────────────────────────────────────────────
      textTheme: textTheme.copyWith(
        // Title in the custom title bar.
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.3,
          color: AppColors.textPrimary,
        ),
        // Message body text.
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 13.5,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        // Smaller captions (timestamps, labels).
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
        // Input field text.
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 13.5,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Input Decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textMuted,
          fontSize: 13.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),

      // ── Icon Theme ───────────────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 20,
      ),

      // ── Tooltip Theme ────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),

      // ── Scrollbar Theme ──────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AppColors.textMuted.withValues(alpha: 0.3),
        ),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}
