import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/presentation/screens/assistant_screen.dart';

/// ── Invisible AI App ───────────────────────────────────────────────────────
/// Root MaterialApp with dark futuristic theme and transparent background.
/// No debug banner. Home screen is the floating assistant overlay.
class InvisibleAIApp extends StatelessWidget {
  const InvisibleAIApp({super.key});

  @override
  Widget build(BuildContext context) {
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
