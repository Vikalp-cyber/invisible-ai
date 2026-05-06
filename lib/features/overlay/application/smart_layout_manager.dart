import 'dart:ui';

import '../../../core/utils/window_utils.dart';
import '../domain/models/overlay_layout_state.dart';
import 'snap_engine.dart';

class SmartLayoutManager {
  SmartLayoutManager({SnapEngine? snapEngine})
      : _snapEngine = snapEngine ?? const SnapEngine();

  final SnapEngine _snapEngine;

  Future<OverlayLayoutState> initialLayout({
    required Size desiredSize,
    String workspaceId = 'default',
  }) async {
    final centered = await WindowUtils.getCenteredPosition(desiredSize);
    return OverlayLayoutState(
      position: centered,
      size: desiredSize,
      workspaceId: workspaceId,
    );
  }

  Future<OverlayLayoutState> clampWithinScreen(OverlayLayoutState current) async {
    final clamped = await WindowUtils.clampToScreen(current.position, current.size);
    return current.copyWith(position: clamped);
  }

  OverlayLayoutState applySnap({
    required OverlayLayoutState current,
    required Size screenSize,
  }) {
    final result = _snapEngine.resolve(
      position: current.position,
      size: current.size,
      screenSize: screenSize,
    );
    return current.copyWith(position: result.position, dockEdge: result.edge);
  }

  OverlayLayoutState dockPreset({
    required DockEdge edge,
    required Size size,
    required Size screenSize,
    required OverlayLayoutState base,
  }) {
    final position = switch (edge) {
      DockEdge.left => const Offset(0, 0),
      DockEdge.right => Offset(screenSize.width - size.width, 0),
      DockEdge.top => const Offset(0, 0),
      DockEdge.bottom => Offset(0, screenSize.height - size.height),
      DockEdge.floating => base.position,
    };
    return base.copyWith(position: position, size: size, dockEdge: edge);
  }
}
