import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// ── Glass Container ────────────────────────────────────────────────────────
/// A reusable glassmorphism container widget that provides:
/// - Backdrop blur effect for frosted glass appearance
/// - Semi-transparent surface with subtle gradient
/// - Optional glowing border
/// - Configurable border radius and padding
///
/// Used as the base for the main window, message bubbles, and input fields.
class GlassContainer extends StatelessWidget {
  /// The child widget to render inside the glass container.
  final Widget child;

  /// Corner radius for the container. Defaults to [AppConstants.cardBorderRadius].
  final double borderRadius;

  /// Internal padding. Defaults to zero.
  final EdgeInsets padding;

  /// External margin. Defaults to zero.
  final EdgeInsets margin;

  /// Whether to show the glowing cyan border.
  final bool showBorder;

  /// Optional gradient overlay for the glass surface.
  final Gradient? gradient;

  /// Optional background color override (applied with opacity).
  final Color? backgroundColor;

  /// Blur strength override. Defaults to [AppConstants.blurSigma].
  final double? blurSigma;

  /// Optional box shadow list.
  final List<BoxShadow>? boxShadow;

  /// Enables expensive blur pass. Disable on low-performance modes.
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = AppConstants.cardBorderRadius,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.showBorder = true,
    this.gradient,
    this.backgroundColor,
    this.blurSigma,
    this.boxShadow,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final sigma = blurSigma ?? AppConstants.blurSigma;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            // The frosted glass blur effect.
            filter: enableBlur
                ? ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                // Semi-transparent surface color.
                color: backgroundColor ??
                    Colors.white.withValues(
                        alpha: AppConstants.glassSurfaceOpacity),
                // Optional gradient overlay for depth.
                gradient: gradient ?? AppColors.glassGradient,
                borderRadius: BorderRadius.circular(borderRadius),
                // Subtle glowing border.
                border: showBorder
                    ? Border.all(
                        color: AppColors.glassBorder,
                        width: 1,
                      )
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
