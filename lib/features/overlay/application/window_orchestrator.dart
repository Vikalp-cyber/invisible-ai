import 'dart:ui';

import '../domain/models/overlay_layout_state.dart';
import '../domain/models/window_descriptor.dart';
import '../infrastructure/window_service_adapter.dart';

class WindowOrchestrator {
  WindowOrchestrator(this._adapter);

  final WindowServiceAdapter _adapter;
  final Map<String, OverlayLayoutState> _states = {};

  OverlayLayoutState? stateFor(String windowId) => _states[windowId];

  Future<void> registerWindow(
    WindowDescriptor descriptor,
    OverlayLayoutState initialState,
  ) async {
    _states[descriptor.id] = initialState;
    if (descriptor.id == OverlayWindowIds.main) {
      await _adapter.move(initialState.position);
      await _adapter.resize(initialState.size);
      await _adapter.setOpacity(initialState.opacity);
    }
  }

  Future<void> updateLayout(String windowId, OverlayLayoutState next) async {
    _states[windowId] = next;
    if (windowId != OverlayWindowIds.main) {
      return;
    }
    await _adapter.move(next.position);
    await _adapter.resize(next.size);
    await _adapter.setOpacity(next.opacity);
  }

  Future<void> setVisible(String windowId, bool visible) async {
    if (windowId != OverlayWindowIds.main) {
      return;
    }
    if (visible) {
      await _adapter.show();
    } else {
      await _adapter.hide();
    }
  }

  Future<void> focusWindow(String windowId) async {
    if (windowId == OverlayWindowIds.main) {
      await _adapter.focus();
    }
  }

  Future<void> dockMainWindow(
    DockEdge edge,
    Size size,
    Size screenSize,
  ) async {
    await _adapter.applyDock(edge, size, screenSize);
    final previous = _states[OverlayWindowIds.main];
    if (previous != null) {
      Offset newPosition;
      switch (edge) {
        case DockEdge.left:
          newPosition = const Offset(0, 0);
        case DockEdge.right:
          newPosition = Offset(screenSize.width - size.width, 0);
        case DockEdge.top:
          newPosition = const Offset(0, 0);
        case DockEdge.bottom:
          newPosition = Offset(0, screenSize.height - size.height);
        case DockEdge.floating:
          newPosition = previous.position;
      }
      _states[OverlayWindowIds.main] = previous.copyWith(
        dockEdge: edge,
        size: size,
        position: newPosition,
      );
    }
  }
}
