import 'dart:ui';

import '../../../services/window_service.dart';
import '../domain/models/overlay_layout_state.dart';

class WindowServiceAdapter {
  WindowServiceAdapter(this._windowService);

  final WindowService _windowService;

  Future<void> show() => _windowService.showWindow();
  Future<void> hide() => _windowService.hideWindow();
  Future<void> focus() => _windowService.bringToFront();
  Future<void> setAlwaysOnTop(bool enabled) async {
    final current = _windowService.isAlwaysOnTop;
    if (current != enabled) {
      await _windowService.toggleAlwaysOnTop();
    }
  }

  Future<void> move(Offset offset) => _windowService.setPosition(offset);
  Future<void> resize(Size size) => _windowService.setSize(size);
  Future<Offset> currentPosition() => _windowService.getPosition();
  Future<Size> currentSize() => _windowService.getSize();
  Future<void> setOpacity(double opacity) => _windowService.setOpacity(opacity);

  Future<void> applyDock(DockEdge edge, Size size, Size screenSize) async {
    Offset position;
    switch (edge) {
      case DockEdge.left:
        position = const Offset(0, 0);
      case DockEdge.right:
        position = Offset(screenSize.width - size.width, 0);
      case DockEdge.top:
        position = const Offset(0, 0);
      case DockEdge.bottom:
        position = Offset(0, screenSize.height - size.height);
      case DockEdge.floating:
        return;
    }
    await resize(size);
    await move(position);
  }
}
