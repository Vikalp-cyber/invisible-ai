import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// ── Typing Indicator ───────────────────────────────────────────────────────
/// Shows three animated bouncing dots with a "AI is thinking..." label.
/// Displayed at the bottom of the response area when the AI is processing.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.horizontalPadding,
        right: 48,
        bottom: 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glass-styled container for the dots.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Three bouncing dots with staggered delays.
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
                const SizedBox(width: 10),

                // "AI is thinking..." label.
                Text(
                  'AI is thinking',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, curve: Curves.easeOut);
  }

  /// Builds a single animated dot with a staggered bounce delay.
  Widget _buildDot(int index) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.7),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .scaleXY(
          begin: 0.6,
          end: 1.0,
          duration: 600.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.easeInOut,
        )
        .moveY(
          begin: 0,
          end: -4,
          duration: 600.ms,
          delay: Duration(milliseconds: index * 150),
          curve: Curves.easeInOut,
        );
  }
}
