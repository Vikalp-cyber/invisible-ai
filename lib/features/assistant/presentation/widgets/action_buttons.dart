import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../overlay/domain/models/overlay_layout_state.dart';
import '../../../overlay/domain/models/overlay_mode.dart';
import '../../../overlay/presentation/providers/overlay_provider.dart';
import '../providers/assistant_provider.dart';
import '../../domain/repositories/ai_provider_interface.dart';

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
    final overlayNotifier = ref.read(overlayProvider.notifier);

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
                  _ActionIconButton(
                    icon: Icons.crop_free_rounded,
                    tooltip: 'Capture Screen Snippet',
                    onPressed: () => notifier.captureScreen(),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.filter_center_focus_rounded,
                    tooltip: 'Focus mode',
                    onPressed: () => overlayNotifier.setMode(OverlayMode.focus),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.view_compact_alt_rounded,
                    tooltip: 'Compact mode',
                    onPressed: () => overlayNotifier.setMode(OverlayMode.compact),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.pan_tool_alt_rounded,
                    tooltip: 'Click-through mode',
                    onPressed: () => overlayNotifier.setMode(OverlayMode.clickThrough),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Normal mode',
                    onPressed: () => overlayNotifier.setMode(OverlayMode.normal),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.vertical_align_top_rounded,
                    tooltip: 'Dock top',
                    onPressed: () => overlayNotifier.dockTo(DockEdge.top),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.auto_awesome_motion_rounded,
                    tooltip: 'Toggle auto-hide',
                    onPressed: () {
                      final enabled = ref.read(overlayProvider).layout.autoHideEnabled;
                      overlayNotifier.setAutoHide(!enabled);
                    },
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.hearing_rounded,
                    tooltip: AppStrings.audioRouteSetupTooltip,
                    onPressed: () => _showAudioRouteSetupDialog(context, notifier),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.graphic_eq_rounded,
                    tooltip: 'Interview copilot audio pipeline',
                    onPressed: () => _showInterviewCopilotDialog(context, ref),
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
                        onPressed: () =>
                            ref.read(assistantProvider.notifier).toggleSpeakerCopilot(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: AppStrings.settingsTooltip,
                    onPressed: () => _showSettingsDialog(context, ref),
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

  /// Shows the settings dialog to configure AI providers and API keys.
  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => const _SettingsDialog());
  }

  void _showAudioRouteSetupDialog(
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
          'Google Meet Audio Setup',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Best practical path: route Meet output to VB-CABLE Input, then use '
          'VB-CABLE Output as app input device. You can inject the full setup '
          'guide into chat and open Windows Sound settings.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final opened = await notifier.openWindowsSoundSettings();
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    opened
                        ? 'Opened Windows sound settings'
                        : 'Could not open sound settings',
                  ),
                ),
              );
            },
            child: const Text(
              'Open Sound Settings',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              await notifier.addVirtualCableSetupGuide();
              if (!ctx.mounted) {
                return;
              }
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Send Guide to Chat',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showInterviewCopilotDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _InterviewCopilotDialog(),
    );
  }
}

class _InterviewCopilotDialog extends ConsumerStatefulWidget {
  const _InterviewCopilotDialog();

  @override
  ConsumerState<_InterviewCopilotDialog> createState() =>
      _InterviewCopilotDialogState();
}

class _InterviewCopilotDialogState extends ConsumerState<_InterviewCopilotDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(assistantProvider.notifier).refreshAudioInputDevices(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantProvider);
    final notifier = ref.read(assistantProvider.notifier);

    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text(
        'Interview Copilot Audio',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Input device (select VB-CABLE Output)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: state.selectedAudioDeviceId,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              items: state.audioDevices
                  .map(
                    (d) => DropdownMenuItem<String>(
                      value: d.id,
                      child: Text(
                        d.isVirtualCable ? '${d.label}  [VB-CABLE]' : d.label,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => notifier.selectAudioInputDevice(value),
            ),
            const SizedBox(height: 10),
            Text(
              state.transcriptPreview.isEmpty
                  ? 'Transcript preview will appear here...'
                  : state.transcriptPreview,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => notifier.refreshAudioInputDevices(),
          child: const Text('Refresh Devices'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (state.isInterviewCopilotActive) {
              await notifier.stopInterviewCopilot();
            } else {
              await notifier.startInterviewCopilot();
            }
            if (mounted) {
              setState(() {});
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(state.isInterviewCopilotActive ? 'Stop' : 'Start'),
        ),
      ],
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  final Map<AIProviderType, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final type in AIProviderType.values) {
      _controllers[type] = TextEditingController();
    }
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final storage = ref.read(secureStorageServiceProvider);
    for (final type in AIProviderType.values) {
      final key = await storage.getApiKey(type);
      if (key != null) {
        _controllers[type]!.text = key;
      }
    }
  }

  Future<void> _saveKeys() async {
    final storage = ref.read(secureStorageServiceProvider);
    for (final type in AIProviderType.values) {
      if (_controllers[type]!.text.trim().isNotEmpty) {
        await storage.saveApiKey(type, _controllers[type]!.text.trim());
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentProviderType = ref.watch(
      assistantProvider.select(
        (s) => ref.read(assistantProvider.notifier).currentProviderType,
      ),
    );

    return AlertDialog(
      backgroundColor: AppColors.backgroundDark,
      title: const Text(
        'AI Settings',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Provider',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<AIProviderType>(
              value: currentProviderType,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary),
              isExpanded: true,
              items: AIProviderType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(assistantProvider.notifier).switchProvider(val);
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'API Keys',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...AIProviderType.values.map((type) {
              if (type == AIProviderType.ollama) {
                return const SizedBox.shrink(); // Ollama needs no key
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  controller: _controllers[type],
                  obscureText: true,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: '${type.displayName} API Key',
                    labelStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _saveKeys,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Save'),
        ),
      ],
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
                  : (_isHovered ? AppColors.glassWhiteHover : Colors.transparent),
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
