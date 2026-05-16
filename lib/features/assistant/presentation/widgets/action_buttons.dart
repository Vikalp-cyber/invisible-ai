import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../providers/assistant_provider.dart';


/// ── Action Buttons ─────────────────────────────────────────────────────────
/// A horizontal row of quick-action icon buttons between the response area
/// and the input field.
///
/// Actions:
/// - 🗑️ Clear Chat — Resets the conversation
/// - 📋 Copy Last — Copies the most recent AI response
/// - ⚙️ Settings — Placeholder for future settings panel
class ActionButtons extends ConsumerWidget {
  const ActionButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(assistantProvider.notifier);

    return Container(
      height: AppConstants.actionBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.horizontalPadding,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: AppStrings.clearChatTooltip,
                    onPressed: () => _showClearConfirmation(context, notifier),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.content_copy_rounded,
                    tooltip: AppStrings.copyLastTooltip,
                    onPressed: () => _copyLastResponse(context, notifier),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Regenerate Response',
                    onPressed: () => notifier.regenerateLastResponse(),
                  ),
                  const SizedBox(width: 4),

                  Consumer(
                    builder: (context, ref, _) {
                      final isListening = ref.watch(
                        assistantProvider.select(
                          (s) => s.isInterviewCopilotActive,
                        ),
                      );
                      return _ActionIconButton(
                        icon: isListening
                            ? Icons.stop_circle_rounded
                            : Icons.speaker_phone_rounded,
                        tooltip: isListening
                            ? 'Stop listening to speakers'
                            : 'Listen to speakers (system audio → AI)',
                        isActive: isListening,
                        onPressed: () => ref
                            .read(assistantProvider.notifier)
                            .toggleSpeakerCopilot(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: AppStrings.settingsTooltip,
                    onPressed: () => _showSettingsDialog(context, ref),
                  ),
                  const SizedBox(width: 4),
                  Consumer(
                    builder: (context, ref, _) {
                      final isLoading = ref.watch(
                        authProvider.select((s) => s.isLoading),
                      );
                      return _ActionIconButton(
                        icon: isLoading
                            ? Icons.hourglass_empty_rounded
                            : Icons.logout_rounded,
                        tooltip: isLoading ? 'Signing out...' : 'Logout',
                        onPressed: isLoading
                            ? () {}
                            : () => ref.read(authProvider.notifier).logout(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Message counter ─────────────────────────────────────────────
          Consumer(
            builder: (context, ref, _) {
              final messageCount = ref.watch(
                assistantProvider.select((s) => s.messages.length),
              );
              return Text(
                '$messageCount messages',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation before clearing the chat.
  void _showClearConfirmation(
    BuildContext context,
    AssistantNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        title: const Text(
          'Clear Chat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to clear the conversation?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              notifier.clearChat();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Copies the last AI response to the clipboard.
  void _copyLastResponse(BuildContext context, AssistantNotifier notifier) {
    final lastMessage = notifier.getLastAssistantMessage();
    if (lastMessage != null) {
      Clipboard.setData(ClipboardData(text: lastMessage));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Navigates to the settings page to configure AI providers and API keys.
  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

/// ── Individual Action Icon Button ──────────────────────────────────────────
/// A small glass-styled icon button with tooltip and hover glow effect.
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final highlight = widget.isActive || _isHovered;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: AppConstants.fastAnimation,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppConstants.smallBorderRadius,
              ),
              color: widget.isActive
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : (_isHovered
                        ? AppColors.glassWhiteHover
                        : Colors.transparent),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: highlight ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
