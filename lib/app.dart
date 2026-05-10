import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/presentation/screens/assistant_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';

/// ── Invisible AI App ───────────────────────────────────────────────────────
/// Root MaterialApp with dark futuristic theme and transparent background.
/// No debug banner. Home screen is the floating assistant overlay.
class InvisibleAIApp extends ConsumerWidget {
  const InvisibleAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      // ── App Identity ─────────────────────────────────────────────────────
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,

      // ── Theme ────────────────────────────────────────────────────────────
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // ── Home Screen ──────────────────────────────────────────────────────
      home: authState.isLoading
          ? const _AuthBootstrapLoader()
          : (authState.isAuthenticated
                ? const AssistantScreen()
                : const SignInScreen()),
    );
  }
}

class _AuthBootstrapLoader extends StatelessWidget {
  const _AuthBootstrapLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
