import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/presentation/screens/assistant_screen.dart';

/// ── Flowdesk app root ───────────────────────────────────────────────────────
/// Root MaterialApp with dark futuristic theme and transparent background.
/// No debug banner. Home screen is the floating assistant overlay.
/// Local-only mode: no Google sign-in / backend auth gate.
class FlowdeskApp extends ConsumerWidget {
  const FlowdeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // ── App Identity ─────────────────────────────────────────────────────
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,

      // ── Theme ────────────────────────────────────────────────────────────
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // ── Home Screen ──────────────────────────────────────────────────────
      home: const AssistantScreen(),
    );
  }
}
