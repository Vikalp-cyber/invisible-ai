import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/windows_title_bar.dart';

import '../../../../services/app_update_service.dart';


import '../../../usage/presentation/providers/usage_provider.dart';
import '../../../payments/presentation/widgets/premium_section.dart';
import '../widgets/settings_sidebar.dart';
import '../widgets/settings_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;

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
                  SettingsSidebarItem(title: 'General', icon: Icons.settings_rounded),
                  SettingsSidebarItem(title: 'Account & Usage', icon: Icons.person_rounded),
                  SettingsSidebarItem(title: 'About', icon: Icons.info_outline_rounded),
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
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
        return _buildUsageSettings();
      case 2:
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings saved successfully'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.surface,
                ),
              );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 24),
        const PremiumSection(),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleItem(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SettingsCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

  Widget _buildUsageSettings() {
    final usageState = ref.watch(usageProvider);
    final usage = usageState.usage;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const Text(
          'Account & Usage',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 24),

        if (usageState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (usage == null)
          const Text('Usage data unavailable', style: TextStyle(color: AppColors.textMuted))
        else
          SettingsCard(
            title: usage.name.isNotEmpty ? usage.name : 'Your Account',
            subtitle: usage.email,
            trailing: usage.isActive 
              ? null 
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Inactive', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tokens Remaining', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text('${usage.tokensRemaining}', style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (usage.tokenLimit > 0 ? usage.tokensUsed / usage.tokenLimit : 0.0)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 8,
                    backgroundColor: AppColors.backgroundDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${usage.tokensUsed} used', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    Text('${usage.tokenLimit} limit', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAboutPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/app_icon.png', width: 100, height: 100),
        const SizedBox(height: 24),
        const Text('Flowdesk', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Intelligence everywhere, seamlessly.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 48),
        const Text('© 2024 LuminoAi. All rights reserved.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        const Text('Version 1.0.1', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
