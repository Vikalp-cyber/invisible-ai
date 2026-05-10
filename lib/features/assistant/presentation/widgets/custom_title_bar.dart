import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/assistant_provider.dart';

/// ── Custom Title Bar ───────────────────────────────────────────────────────
/// A frameless, draggable title bar with:
/// - AI brain icon with animated glow
/// - App title "Invisible AI"
/// - Active status indicator (green pulsing dot)
/// - Hotkey hint badge
/// - Always-on-top toggle (pin icon)
/// - Minimize button
/// - Close button (hides to system tray)
///
/// Uses bitsdojo_window's MoveWindow for native Win32 drag support.
class CustomTitleBar extends ConsumerWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assistantProvider);
    final notifier = ref.read(assistantProvider.notifier);

    return SizedBox(
      height: AppConstants.titleBarHeight,
      child: Container(
        decoration: const BoxDecoration(
          // Subtle gradient from cyan-tinted top to transparent.
          gradient: AppColors.titleBarGradient,
          // Bottom separator line.
          border: Border(
            bottom: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // ── Drag Area (left side — icon, title, status) ────────────────
            Expanded(
              child: MoveWindow(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.horizontalPadding,
                  ),
                  child: Row(
                    children: [
                      // AI brain icon with animated glow.
                      _buildAppIcon(),
                      const SizedBox(width: 10),

                      // App title.
                      Flexible(
                        child: Text(
                          AppStrings.appTitle,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Active status dot.
                      _buildStatusDot(),

                      // Only show hotkey hint if there's enough space.
                      const Spacer(),
                      _buildHotkeyHint(context),
                    ],
                  ),
                ),
              ),
            ),

            // ── Window Control Buttons (right side) ────────────────────────
            _buildPinButton(state.isAlwaysOnTop, notifier),
            _buildControlButton(
              icon: Icons.remove_rounded,
              tooltip: AppStrings.minimizeTooltip,
              onPressed: () => notifier.minimizeWindow(),
            ),
            _buildControlButton(
              icon: Icons.close_rounded,
              tooltip: AppStrings.hideToTrayTooltip,
              onPressed: () => notifier.closeWindow(),
              isClose: true,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// AI brain icon with a subtle animated cyan glow.
  Widget _buildAppIcon() {
    return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: AppColors.textOnPrimary,
            size: 18,
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(
          duration: 3.seconds,
          color: AppColors.primary.withValues(alpha: 0.15),
        );
  }

  /// Green pulsing dot indicating active status.
  Widget _buildStatusDot() {
    return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 0.8,
          end: 1.0,
          duration: 1500.ms,
          curve: Curves.easeInOut,
        );
  }

  /// Hotkey hint badge — shows the shortcut to toggle the overlay.
  Widget _buildHotkeyHint(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: AppColors.glassWhite,
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Text(
        AppConstants.defaultToggleHotkeyDisplay,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 9,
          color: AppColors.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Always-on-top pin toggle button with active/inactive styling.
  Widget _buildPinButton(bool isAlwaysOnTop, AssistantNotifier notifier) {
    return Tooltip(
      message: isAlwaysOnTop ? AppStrings.unpinTooltip : AppStrings.pinTooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => notifier.toggleAlwaysOnTop(),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              isAlwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 16,
              color: isAlwaysOnTop ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// Generic window control button (minimize / close).
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: isClose
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.glassWhiteHover,
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: isClose ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
