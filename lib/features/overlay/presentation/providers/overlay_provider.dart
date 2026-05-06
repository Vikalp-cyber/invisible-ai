import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../assistant/presentation/providers/assistant_provider.dart';
import '../../application/overlay_notification_center.dart';
import '../../application/smart_layout_manager.dart';
import '../../application/window_orchestrator.dart';
import '../../domain/models/overlay_layout_state.dart';
import '../../domain/models/overlay_mode.dart';
import '../../domain/models/window_descriptor.dart';
import '../../infrastructure/window_service_adapter.dart';
import '../../infrastructure/workspace_memory_store.dart';

final workspaceMemoryStoreProvider = Provider<WorkspaceMemoryStore>((ref) {
  final prefs = ref.watch(preferenceServiceProvider);
  return WorkspaceMemoryStore(prefs);
});

final smartLayoutManagerProvider = Provider<SmartLayoutManager>((ref) {
  return SmartLayoutManager();
});

final windowOrchestratorProvider = Provider<WindowOrchestrator>((ref) {
  final windowService = ref.watch(windowServiceProvider);
  return WindowOrchestrator(WindowServiceAdapter(windowService));
});

final overlayNotificationCenterProvider =
    NotifierProvider<OverlayNotificationCenter, List<OverlayNotificationItem>>(
  OverlayNotificationCenter.new,
);

class OverlayState {
  const OverlayState({
    required this.layout,
    this.isHovering = false,
    this.mode = OverlayMode.normal,
  });

  final OverlayLayoutState layout;
  final bool isHovering;
  final OverlayMode mode;

  OverlayState copyWith({
    OverlayLayoutState? layout,
    bool? isHovering,
    OverlayMode? mode,
  }) {
    return OverlayState(
      layout: layout ?? this.layout,
      isHovering: isHovering ?? this.isHovering,
      mode: mode ?? this.mode,
    );
  }
}

class OverlayNotifier extends Notifier<OverlayState> {
  late final WorkspaceMemoryStore _workspaceStore;
  late final SmartLayoutManager _layoutManager;
  late final WindowOrchestrator _orchestrator;
  Timer? _autoHideTimer;

  @override
  OverlayState build() {
    _workspaceStore = ref.watch(workspaceMemoryStoreProvider);
    _layoutManager = ref.watch(smartLayoutManagerProvider);
    _orchestrator = ref.watch(windowOrchestratorProvider);

    final restored = _workspaceStore.read();
    final normalizedRestored = restored != null &&
            restored.mode == OverlayMode.clickThrough
        ? restored.copyWith(
            mode: OverlayMode.normal,
            opacity: 0.95,
          )
        : restored;
    final initial = normalizedRestored ??
        const OverlayLayoutState(
          position: Offset(100, 100),
          size: AppConstants.defaultWindowSize,
        );

    _orchestrator.registerWindow(
      const WindowDescriptor(id: OverlayWindowIds.main, isPrimary: true),
      initial,
    );

    ref.onDispose(() {
      _autoHideTimer?.cancel();
    });

    if (normalizedRestored != null && restored != null) {
      // Safety: never restore startup state into click-through mode, otherwise
      // the app can become unclickable after restart.
      _workspaceStore.save(normalizedRestored);
    }

    return OverlayState(layout: initial, mode: initial.mode);
  }

  Future<void> initializeSmartLayout() async {
    if (_workspaceStore.read() != null) {
      return;
    }
    final initial = await _layoutManager.initialLayout(
      desiredSize: AppConstants.defaultWindowSize,
    );
    state = state.copyWith(layout: initial, mode: initial.mode);
    await _orchestrator.updateLayout(OverlayWindowIds.main, initial);
    await _workspaceStore.save(initial);
  }

  Future<void> setMode(OverlayMode mode) async {
    var next = state.layout.copyWith(mode: mode);
    switch (mode) {
      case OverlayMode.compact:
        next = next.copyWith(size: AppConstants.compactWindowSize, expanded: false);
      case OverlayMode.focus:
        next = next.copyWith(
          size: AppConstants.focusWindowSize,
          expanded: true,
          opacity: 1.0,
        );
      case OverlayMode.clickThrough:
        next = next.copyWith(opacity: 0.65);
      case OverlayMode.normal:
        next = next.copyWith(size: AppConstants.defaultWindowSize, opacity: 0.95);
    }
    state = state.copyWith(layout: next, mode: mode);
    await _orchestrator.updateLayout(OverlayWindowIds.main, next);
    final persisted = mode == OverlayMode.clickThrough
        ? next.copyWith(
            mode: OverlayMode.normal,
            opacity: 0.95,
          )
        : next;
    await _workspaceStore.save(persisted);
    _notify('Overlay Mode', 'Switched to ${mode.key.replaceAll('_', ' ')} mode');
  }

  Future<void> setExpanded(bool expanded) async {
    final next = state.layout.copyWith(expanded: expanded);
    state = state.copyWith(layout: next);
    await _workspaceStore.save(next);
  }

  Future<void> dockTo(DockEdge edge) async {
    final display = PlatformDispatcher.instance.displays.first;
    final screenSize = display.size / display.devicePixelRatio;
    final next = _layoutManager.dockPreset(
      edge: edge,
      size: state.layout.size,
      screenSize: screenSize,
      base: state.layout,
    );
    state = state.copyWith(layout: next);
    await _orchestrator.dockMainWindow(edge, next.size, screenSize);
    await _workspaceStore.save(next);
    _notify('Docked', 'Window docked to ${edge.name}');
  }

  Future<void> setAutoHide(bool enabled) async {
    final next = state.layout.copyWith(autoHideEnabled: enabled);
    state = state.copyWith(layout: next);
    await _workspaceStore.save(next);
    _notify('Auto Hide', enabled ? 'Auto-hide enabled' : 'Auto-hide disabled');
    if (!enabled) {
      _autoHideTimer?.cancel();
      await _orchestrator.setVisible(OverlayWindowIds.main, true);
    }
  }

  void onPointerActivity() {
    _autoHideTimer?.cancel();
    if (!state.layout.autoHideEnabled) {
      return;
    }
    _autoHideTimer = Timer(AppConstants.autoHideDelay, () async {
      await _orchestrator.setVisible(OverlayWindowIds.main, false);
    });
  }

  Future<void> revealFromAutoHide() async {
    if (state.layout.autoHideEnabled) {
      await _orchestrator.setVisible(OverlayWindowIds.main, true);
      await _orchestrator.focusWindow(OverlayWindowIds.main);
    }
  }

  void setHovering(bool hovering) {
    state = state.copyWith(isHovering: hovering);
    if (hovering) {
      revealFromAutoHide();
    }
  }

  void _notify(String title, String message) {
    ref.read(overlayNotificationCenterProvider.notifier).push(
          title: title,
          message: message,
        );
  }
}

final overlayProvider = NotifierProvider<OverlayNotifier, OverlayState>(
  OverlayNotifier.new,
);
