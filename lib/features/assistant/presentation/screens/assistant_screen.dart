import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion_tokens.dart';
import '../../../overlay/domain/models/overlay_layout_state.dart';
import '../../../overlay/domain/models/overlay_mode.dart';
import '../../../overlay/presentation/providers/overlay_provider.dart';
import '../../../overlay/presentation/widgets/dock_handle.dart';
import '../../../overlay/presentation/widgets/floating_widget_host.dart';
import '../../../overlay/presentation/widgets/overlay_notifications.dart';
import '../../../overlay/presentation/widgets/snap_preview_overlay.dart';
import '../providers/assistant_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/ai_response_area.dart';
import '../widgets/action_buttons.dart';
import '../widgets/input_text_area.dart';

/// ── Assistant Screen ───────────────────────────────────────────────────────
/// The main overlay screen that assembles all UI sections into the floating
/// AI assistant panel.
///
/// Layout (top to bottom):
/// 1. Custom Title Bar — draggable, with window controls (hides to tray)
/// 2. AI Response Area — scrollable message list (expanded)
/// 3. Action Buttons — quick actions row
/// 4. Input Text Area — message input with auto-focus on hotkey toggle
///
/// The entire screen is wrapped in a [GlassContainer] with rounded corners
/// and a deep background, giving the floating panel its signature look.
///
/// Animations:
/// - Smooth scale + fade entry animation on app launch
/// - Listens to overlay visibility state for future animated transitions
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Entry animation controller.
    _animController = AnimationController(
      duration: AppConstants.overlayShowDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    // Play the entry animation on first build.
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch overlay visibility for potential future animated transitions.
    ref.watch(assistantProvider.select((state) => state.isOverlayVisible));
    final overlayState = ref.watch(overlayProvider);
    final overlayNotifier = ref.read(overlayProvider.notifier);
    final isClickThrough = overlayState.mode == OverlayMode.clickThrough;

    return Scaffold(
      // Transparent scaffold to let the glass effect show through.
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => overlayNotifier.setHovering(true),
        onExit: (_) => overlayNotifier.setHovering(false),
        onHover: (_) => overlayNotifier.onPointerActivity(),
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Center(
                  child: RepaintBoundary(
                    child: AnimatedScale(
                      duration: MotionTokens.normal,
                      curve: MotionTokens.smoothInOut,
                      scale: overlayState.mode == OverlayMode.compact ? 0.94 : 1.0,
                      child: IgnorePointer(
                        ignoring: isClickThrough,
                        child: GlassContainer(
                          borderRadius: AppConstants.windowBorderRadius,
                          showBorder: true,
                          // Deep navy background with glass overlay.
                          backgroundColor: AppColors.backgroundDark.withValues(
                            alpha: overlayState.layout.opacity.clamp(0.5, 1.0),
                          ),
                          boxShadow: AppColors.windowShadow,
                          child: Stack(
                            children: [
                              Column(
                                children: const [
                                  CustomTitleBar(),
                                  Expanded(child: AIResponseArea()),
                                  ActionButtons(),
                                  InputTextArea(),
                                  SizedBox(height: 4),
                                ],
                              ),
                              DockHandle(
                                onTap: () => overlayNotifier.dockTo(
                                  overlayState.layout.dockEdge == DockEdge.floating
                                      ? DockEdge.top
                                      : DockEdge.floating,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SnapPreviewOverlay(edge: overlayState.layout.dockEdge),
            FloatingWidgetHost(visible: overlayState.mode == OverlayMode.focus),
            const OverlayNotifications(),
          ],
        ),
      ),
    );
  }
}
