import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/windows_title_bar.dart';
import '../providers/auth_provider.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // ── Background Depth ───────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.backgroundDark,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundGridPainter(),
            ),
          ),

          // ── Main Content ───────────────────────────────────────────────────
          Column(
            children: [
              const WindowsTitleBar(title: 'Invisible AI Assistant'),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppColors.glassGradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.glassBorder,
                              width: 1,
                            ),
                            boxShadow: AppColors.windowShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ── Logo ───────────────────────────────────────
                                  Image.asset(
                                    'assets/app_icon.png',
                                    width: 72,
                                    height: 72,
                                  ).animate(
                                    target: authState.isLoading ? 1 : 0,
                                    onPlay: (controller) => controller.repeat(reverse: true),
                                  ).scale(
                                        begin: const Offset(1, 1),
                                        end: const Offset(1.1, 1.1),
                                        duration: 1000.ms,
                                        curve: Curves.easeInOut,
                                      ).animate(
                                        target: 0, // Initial entry animation
                                      ).scale(
                                        duration: 600.ms,
                                        curve: Curves.easeOutBack,
                                      ),
                                  const SizedBox(height: 20),

                                  // ── Title ──────────────────────────────────────
                                  const Text(
                                    'Welcome Back',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ).animate().fadeIn(delay: 200.ms).moveY(
                                        begin: 10,
                                        end: 0,
                                        duration: 400.ms,
                                      ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Your invisible intelligence awaits.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ).animate().fadeIn(delay: 300.ms),
                                  const SizedBox(height: 32),

                                  // ── Sign In Button ─────────────────────────────
                                  _GoogleSignInButton(
                                    isLoading: authState.isLoading,
                                    onPressed: () => notifier.signInWithGoogle(),
                                  ).animate().fadeIn(delay: 400.ms).moveY(
                                        begin: 20,
                                        end: 0,
                                        duration: 500.ms,
                                      ),

                                  if (authState.error != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      authState.error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12,
                                      ),
                                    ).animate().shake(),
                                  ],

                                  const SizedBox(height: 20),
                                  const Text(
                                    'Secure authentication via browser.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Full-Screen Premium Loading Overlay ─────────────────────────────
          if (authState.isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: AppColors.backgroundDark.withValues(alpha: 0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Ethereal Pulse Loader ───────────────────────────
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer sonar ring 1
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                              ),
                            ).animate(onPlay: (c) => c.repeat())
                             .scale(begin: const Offset(1, 1), end: const Offset(2.5, 2.5), duration: 2000.ms, curve: Curves.linear)
                             .fadeOut(duration: 2000.ms),

                            // Outer sonar ring 2
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
                              ),
                            ).animate(onPlay: (c) => c.repeat())
                             .scale(delay: 1000.ms, begin: const Offset(1, 1), end: const Offset(2.5, 2.5), duration: 2000.ms, curve: Curves.linear)
                             .fadeOut(duration: 2000.ms),
                            
                            // Central glowing core
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.6),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1500.ms, curve: Curves.easeInOut),
                          ],
                        ),
                        const SizedBox(height: 50),
                        
                        // ── Animated Text ────────────────────────────────────
                        const Text(
                          'PREPARING YOUR WORKSPACE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ).animate(onPlay: (c) => c.repeat())
                         .shimmer(duration: 2500.ms, color: AppColors.primary.withValues(alpha: 0.5))
                         .fadeIn(duration: 800.ms),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Checking permissions and quotas...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .fadeIn(duration: 1000.ms)
                         .then()
                         .fadeOut(duration: 1000.ms),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms),
            ),
        ],
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: 200.ms,
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _isHovered
              ? AppColors.primaryGradient
              : null,
          color: _isHovered ? null : Colors.white,
          boxShadow: _isHovered ? AppColors.glowShadow : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Simulating Google Icon with a generic one if asset is missing,
                        // but let's assume standard icon for now.
                        Icon(
                          Icons.login_rounded,
                          color: _isHovered ? Colors.black : Colors.black87,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: _isHovered ? Colors.black : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (var i = 0.0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

