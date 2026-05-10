import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../overlay/domain/models/overlay_layout_state.dart';
import '../../../overlay/domain/models/overlay_mode.dart';
import '../../../overlay/presentation/providers/overlay_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/assistant_provider.dart';
import '../../../usage/presentation/providers/usage_provider.dart';
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

class _InterviewCopilotDialogState
    extends ConsumerState<_InterviewCopilotDialog> {
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
  int _selectedIndex = 0;

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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: AppColors.backgroundMedium,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 1),
          boxShadow: AppColors.windowShadow,
        ),
        child: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────────────
            Container(
              width: 180,
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.glassBorder, width: 0.5),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildSidebarItem(0, 'AI Providers', Icons.auto_awesome_rounded),
                  _buildSidebarItem(1, 'General', Icons.settings_rounded),
                  _buildSidebarItem(2, 'Usage', Icons.pie_chart_rounded),
                  _buildSidebarItem(3, 'About', Icons.info_outline_rounded),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content Area ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                      _selectedIndex == 0
                          ? 'AI Providers'
                          : (_selectedIndex == 1
                              ? 'General Settings'
                              : (_selectedIndex == 2 ? 'Profile & Usage' : 'About')),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _selectedIndex == 0
                          ? _buildAIProviders()
                          : (_selectedIndex == 1
                              ? _buildGeneralSettings()
                              : (_selectedIndex == 2
                                  ? _buildUsageSettings()
                                  : _buildAboutPage())),
                    ),
                  ),

                  // ── Actions ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.glassBorder, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _saveKeys,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIProviders() {
    final currentProviderType = ref.watch(
      assistantProvider.select(
        (s) => ref.read(assistantProvider.notifier).currentProviderType,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Active Model Provider',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AIProviderType>(
              value: currentProviderType,
              dropdownColor: AppColors.backgroundMedium,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
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
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'API Configuration',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...AIProviderType.values.map((type) {
          if (type == AIProviderType.ollama) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _controllers[type],
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter API Key',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.glassBorder, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildSettingToggle(
          'Always on Top',
          'Keep the assistant visible above other windows',
          true, // Should be linked to state
          (val) {},
        ),
        _buildSettingToggle(
          'Start with Windows',
          'Launch Invisible AI automatically when you sign in',
          false,
          (val) {},
        ),
        _buildSettingToggle(
          'Compact Mode',
          'Use a smaller interface for the assistant',
          false,
          (val) {},
        ),
      ],
    );
  }

  Widget _buildSettingToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSettings() {
    final usageState = ref.watch(usageProvider);

    if (usageState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (usageState.error != null && usageState.usage == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            'Error: ${usageState.error}',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      );
    }

    final usage = usageState.usage;
    if (usage == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text(
            'Usage data unavailable.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final double progress = usage.tokenLimit > 0 
        ? usage.tokensUsed / usage.tokenLimit 
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    usage.name.isNotEmpty ? usage.name : 'Your Account',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!usage.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Inactive',
                        style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              if (usage.email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  usage.email,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tokens Remaining',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  Text(
                    '${usage.tokensRemaining}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.backgroundMedium,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${usage.tokensUsed} used',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  Text(
                    '${usage.tokenLimit} total limit',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton(
            onPressed: () {
              // Placeholder for upgrade URL
              launchUrl(Uri.parse('https://example.com/upgrade'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
            child: const Text('Upgrade Plan'),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Image.asset('assets/app_icon.png', width: 80, height: 80),
        const SizedBox(height: 16),
        const Text(
          'Invisible AI Assistant',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Intelligence everywhere, seamlessly.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 40),
        const Text(
          '© 2024 Vikalp Cyber. All rights reserved.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
