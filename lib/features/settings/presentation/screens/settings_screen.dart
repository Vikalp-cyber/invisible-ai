import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/windows_title_bar.dart';

import '../../../../services/app_update_service.dart';

import '../../../assistant/data/providers/groq_config_providers.dart';
import '../../../assistant/data/providers/cursor_config_providers.dart';
import '../providers/resume_provider.dart';
import '../widgets/settings_sidebar.dart';
import '../widgets/settings_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _cursorKeyController = TextEditingController();
  final TextEditingController _resumeController = TextEditingController();
  bool _obscureNewKey = true;
  bool _obscureCursorKey = true;
  bool _resumeEditorSynced = false;
  bool _isImportingResume = false;

  @override
  void dispose() {
    _groqKeyController.dispose();
    _cursorKeyController.dispose();
    _resumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // ── Background Glow ────────────────────────────────────────────────
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Row(
            children: [
              // ── Sidebar ────────────────────────────────────────────────────
              SettingsSidebar(
                selectedIndex: _selectedIndex,
                onSelected: (index) => setState(() => _selectedIndex = index),
                items: const [
                  SettingsSidebarItem(
                    title: 'General',
                    icon: Icons.settings_rounded,
                  ),
                  SettingsSidebarItem(
                    title: 'API Keys',
                    icon: Icons.key_rounded,
                  ),
                  SettingsSidebarItem(
                    title: 'Resume',
                    icon: Icons.description_outlined,
                  ),
                  SettingsSidebarItem(
                    title: 'About',
                    icon: Icons.info_outline_rounded,
                  ),
                ],
              ),

              // ── Content Area ───────────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundMedium.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      const WindowsTitleBar(
                        title: '',
                        actions: [],
                      ),
                      Expanded(
                        child: _buildContent(),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Back Button ────────────────────────────────────────────────────
          Positioned(
            top: 48,
            left: 12,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back to Assistant',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildGeneralSettings();
      case 1:
        return _buildApiKeysSettings();
      case 2:
        return _buildResumeSettings();
      case 3:
        return _buildAboutPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'General',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        _buildToggleItem(
          'Always on Top',
          'Keep the assistant visible above other windows',
          true,
          (val) {},
        ),
        _buildToggleItem(
          'Start with Windows',
          'Launch Flowdesk automatically when you sign in',
          false,
          (val) {},
        ),
        _buildToggleItem(
          'Compact Mode',
          'Use a smaller interface for the assistant',
          false,
          (val) {},
        ),
        if (Platform.isWindows) ...[
          const SizedBox(height: 16),
          SettingsCard(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AppUpdateService.presentManualCheck(context),
                icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('Check for updates'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.glassBorder),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleItem(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SettingsCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysSettings() {
    final groqKeysAsync = ref.watch(localGroqKeysProvider);
    final cursorKeysAsync = ref.watch(localCursorKeysProvider);

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'API Keys',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cursor keys power interview chat (uses your Cursor plan). Groq keys '
          'are optional for speech fallback. On Windows, microphone copilot '
          'uses free built-in speech recognition first (no Groq calls).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        const Text(
          'Cursor (chat)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Add Cursor key',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _cursorKeyController,
                obscureText: _obscureCursorKey,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Paste crsr_… key from cursor.com/dashboard/api',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundDark.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCursorKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCursorKey = !_obscureCursorKey),
                  ),
                ),
                onSubmitted: (_) => _addCursorKey(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _addCursorKey,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        cursorKeysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Failed to load Cursor keys: $e',
            style: const TextStyle(color: AppColors.error),
          ),
          data: (keys) => _buildSavedKeysList(
            keys: keys,
            emptyMessage:
                'No Cursor keys saved yet. Paste your key above — chat will use your Cursor plan.',
            onRemove: _removeCursorKeyAt,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Groq (speech + fallback chat)',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SettingsCard(
          title: 'Add Groq key',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _groqKeyController,
                obscureText: _obscureNewKey,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Paste gsk_… key',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundDark.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewKey = !_obscureNewKey),
                  ),
                ),
                onSubmitted: (_) => _addGroqKey(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _addGroqKey,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        groqKeysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Failed to load Groq keys: $e',
            style: const TextStyle(color: AppColors.error),
          ),
          data: (keys) => _buildSavedKeysList(
            keys: keys,
            emptyMessage:
                'No Groq keys saved. Optional on Windows — mic copilot uses free '
                'built-in speech. Groq is still used for speaker/loopback mode.',
            onRemove: _removeGroqKeyAt,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedKeysList({
    required List<String> keys,
    required String emptyMessage,
    required Future<void> Function(int index) onRemove,
  }) {
    if (keys.isEmpty) {
      return SettingsCard(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saved keys (${keys.length})',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < keys.length; i++)
          SettingsCard(
            title: i == 0 ? 'Primary' : 'Fallback $i',
            trailing: IconButton(
              tooltip: 'Remove key',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              onPressed: () => onRemove(i),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _maskKey(keys[i]),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy key',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: keys[i]));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Key copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _addCursorKey() async {
    final raw = _cursorKeyController.text.trim();
    if (raw.isEmpty) return;

    final before =
        ref.read(localCursorKeysProvider).asData?.value ?? const <String>[];
    await ref.read(localCursorKeysProvider.notifier).addKey(raw);
    final after =
        ref.read(localCursorKeysProvider).asData?.value ?? const <String>[];

    _cursorKeyController.clear();
    if (!mounted) return;

    final added = after.length > before.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Cursor key saved — chat will use your Cursor plan'
              : 'Key was empty or already saved',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _removeCursorKeyAt(int index) async {
    await ref.read(localCursorKeysProvider.notifier).removeAt(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cursor key removed'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _addGroqKey() async {
    final raw = _groqKeyController.text.trim();
    if (raw.isEmpty) return;

    final before =
        ref.read(localGroqKeysProvider).asData?.value ?? const <String>[];
    await ref.read(localGroqKeysProvider.notifier).addKey(raw);
    final after =
        ref.read(localGroqKeysProvider).asData?.value ?? const <String>[];

    _groqKeyController.clear();
    if (!mounted) return;

    final added = after.length > before.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Groq key saved locally'
              : 'Key was empty or already saved',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _removeGroqKeyAt(int index) async {
    await ref.read(localGroqKeysProvider.notifier).removeAt(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Key removed'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
  }

  Widget _buildResumeSettings() {
    final resumeAsync = ref.watch(resumeProfileProvider);

    resumeAsync.whenData((profile) {
      if (!_resumeEditorSynced) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _resumeEditorSynced) return;
          _resumeController.text = profile.text;
          _resumeEditorSynced = true;
        });
      }
    });

    final profile = resumeAsync.asData?.value;
    final fileName = profile?.fileName ?? '';
    final charCount = profile?.charCount ?? 0;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'Resume',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste or upload your resume. Interview answers will use this as '
          'ground truth and speak in first person as you.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        SettingsCard(
          title: 'Resume text',
          subtitle: fileName.isEmpty
              ? (charCount == 0
                  ? 'No resume saved yet'
                  : '$charCount characters saved')
              : '$fileName · $charCount characters',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _resumeController,
                maxLines: 14,
                minLines: 8,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste your resume or experience summary here…',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundDark.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isImportingResume ? null : _importResumeFile,
                    icon: _isImportingResume
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 18),
                    label: Text(
                      _isImportingResume ? 'Importing…' : 'Upload PDF / TXT',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.glassBorder),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: charCount == 0 && _resumeController.text.trim().isEmpty
                        ? null
                        : _clearResume,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveResumeText,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveResumeText() async {
    final existingName =
        ref.read(resumeProfileProvider).asData?.value.fileName ?? '';
    await ref.read(resumeProfileProvider.notifier).saveText(
          _resumeController.text,
          fileName: existingName.isNotEmpty ? existingName : 'Pasted text',
        );
    _resumeEditorSynced = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume saved locally'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Future<void> _importResumeFile() async {
    setState(() => _isImportingResume = true);
    try {
      await ref.read(resumeProfileProvider.notifier).importFile();
      final profile = ref.read(resumeProfileProvider).asData?.value;
      if (profile != null) {
        _resumeController.text = profile.text;
        _resumeEditorSynced = true;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resume imported'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isImportingResume = false);
      }
    }
  }

  Future<void> _clearResume() async {
    await ref.read(resumeProfileProvider.notifier).clear();
    _resumeController.clear();
    _resumeEditorSynced = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume cleared'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Widget _buildAboutPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/app_icon.png', width: 100, height: 100),
        const SizedBox(height: 24),
        const Text(
          'Flowdesk',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'Intelligence everywhere, seamlessly.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 48),
        const Text(
          '© 2024 LuminoAi. All rights reserved.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        const Text(
          'Version 1.0.1',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
