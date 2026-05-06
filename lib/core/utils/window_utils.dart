import 'dart:ui';

import 'package:window_manager/window_manager.dart';

/// ── Window Utilities ───────────────────────────────────────────────────────
/// Helper functions for window positioning and DPI-aware calculations.
class WindowUtils {
  WindowUtils._();

  /// Centers the window on the primary monitor given its [windowSize].
  /// Falls back to (100, 100) if screen size can't be determined.
  static Future<Offset> getCenteredPosition(Size windowSize) async {
    try {
      // Use PlatformDispatcher to get the screen size (DPI-aware).
      final display = PlatformDispatcher.instance.displays.first;
      final screenSize = display.size / display.devicePixelRatio;

      final dx = (screenSize.width - windowSize.width) / 2;
      final dy = (screenSize.height - windowSize.height) / 2;
      final safeDx = dx.isFinite ? dx : 100.0;
      final safeDy = dy.isFinite ? dy : 100.0;

      return Offset(
        safeDx.clamp(0, 100000.0),
        safeDy.clamp(0, 100000.0),
      );
    } catch (_) {
      return const Offset(100, 100);
    }
  }

  /// Ensures a position is within visible screen bounds.
  static Future<Offset> clampToScreen(Offset position, Size windowSize) async {
    try {
      final display = PlatformDispatcher.instance.displays.first;
      final screenSize = display.size / display.devicePixelRatio;

      final dx = position.dx.clamp(0.0, screenSize.width - windowSize.width);
      final dy = position.dy.clamp(0.0, screenSize.height - windowSize.height);

      return Offset(dx, dy);
    } catch (_) {
      return position;
    }
  }

  /// Saves the current window bounds for later restoration.
  static Future<Map<String, double>> getCurrentWindowBounds() async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();

    return {
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
    };
  }
}
