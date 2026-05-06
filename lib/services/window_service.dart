import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/window_utils.dart';
import 'preference_service.dart';

/// ── Window Service ─────────────────────────────────────────────────────────
/// Manages all window lifecycle operations: initialization, state persistence,
/// always-on-top toggle, visibility toggle, minimize, hide-to-tray, and close.
/// Acts as the single source of truth for window configuration.
///
/// Extended to support:
/// - Hide/show window (for tray minimize and hotkey toggle)
/// - Prevent close (intercept close → hide to tray instead)
/// - Focus management (bring window to front + focus input)
class WindowService with WindowListener {
  final PreferenceService _prefs;

  /// Whether the window is currently set to always-on-top.
  bool _isAlwaysOnTop = true;

  /// Whether the overlay window is currently visible.
  bool _isVisible = true;

  /// Whether the close button should hide to tray instead of quitting.
  bool _preventClose = true;

  bool get isAlwaysOnTop => _isAlwaysOnTop;
  bool get isVisible => _isVisible;
  bool get preventClose => _preventClose;

  /// Callback invoked when window visibility changes (for state sync).
  VoidCallback? onVisibilityChanged;

  /// Callback invoked when close is intercepted (hide-to-tray).
  VoidCallback? onCloseIntercepted;

  WindowService(this._prefs);

  /// ── Initialize Window ─────────────────────────────────────────────────────
  /// Sets up the frameless, transparent, always-on-top window with either
  /// persisted or default centered position.
  Future<void> initWindow() async {
    await windowManager.ensureInitialized();

    // Restore persisted always-on-top preference (default: true).
    _isAlwaysOnTop = _prefs.getBool(
      AppConstants.keyAlwaysOnTop,
      defaultValue: true,
    );

    // Determine window size: use persisted values or defaults.
    Size windowSize;
    Offset windowPosition;

    if (_prefs.containsKey(AppConstants.keyWindowWidth)) {
      // Restore persisted window bounds.
      windowSize = Size(
        _prefs.getDouble(AppConstants.keyWindowWidth,
            defaultValue: AppConstants.defaultWindowSize.width),
        _prefs.getDouble(AppConstants.keyWindowHeight,
            defaultValue: AppConstants.defaultWindowSize.height),
      );
      windowPosition = Offset(
        _prefs.getDouble(AppConstants.keyWindowX, defaultValue: 100),
        _prefs.getDouble(AppConstants.keyWindowY, defaultValue: 100),
      );
      // Ensure the restored position is still on-screen.
      windowPosition =
          await WindowUtils.clampToScreen(windowPosition, windowSize);
    } else {
      // First launch: use defaults and center on screen.
      windowSize = AppConstants.defaultWindowSize;
      windowPosition = await WindowUtils.getCenteredPosition(windowSize);
    }

    // Configure window options.
    final windowOptions = WindowOptions(
      size: windowSize,
      minimumSize: AppConstants.minimumWindowSize,
      maximumSize: AppConstants.maximumWindowSize,
      center: false, // We position manually.
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    // Apply options and show the window when ready.
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPosition(windowPosition);
      await windowManager.setAlwaysOnTop(_isAlwaysOnTop);
      await windowManager.setAsFrameless();
      // Enable close interception — close button hides to tray.
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });

    _isVisible = true;

    // Listen for window events (move, resize, close) to persist state.
    windowManager.addListener(this);
  }

  /// ── Save Window State ─────────────────────────────────────────────────────
  /// Persists current window position and size to SharedPreferences.
  Future<void> saveWindowState() async {
    try {
      final bounds = await WindowUtils.getCurrentWindowBounds();
      await _prefs.setDouble(AppConstants.keyWindowX, bounds['x']!);
      await _prefs.setDouble(AppConstants.keyWindowY, bounds['y']!);
      await _prefs.setDouble(AppConstants.keyWindowWidth, bounds['width']!);
      await _prefs.setDouble(AppConstants.keyWindowHeight, bounds['height']!);
    } catch (e) {
      debugPrint('WindowService: Failed to save window state: $e');
    }
  }

  /// ── Toggle Always-On-Top ──────────────────────────────────────────────────
  /// Flips the always-on-top state and persists the preference.
  Future<bool> toggleAlwaysOnTop() async {
    _isAlwaysOnTop = !_isAlwaysOnTop;
    await windowManager.setAlwaysOnTop(_isAlwaysOnTop);
    await _prefs.setBool(AppConstants.keyAlwaysOnTop, _isAlwaysOnTop);
    return _isAlwaysOnTop;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Visibility Management (NEW) ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// ── Toggle Overlay Visibility ─────────────────────────────────────────────
  /// Shows the window if hidden, hides it if visible. Returns the new state.
  Future<bool> toggleVisibility() async {
    if (_isVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
    return _isVisible;
  }

  /// ── Show Window ───────────────────────────────────────────────────────────
  /// Makes the overlay visible, brings it to front, and gives it focus.
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _isVisible = true;
    onVisibilityChanged?.call();
    debugPrint('WindowService: Window shown');
  }

  /// ── Hide Window ───────────────────────────────────────────────────────────
  /// Hides the overlay window (it remains running in the background).
  /// Saves window state before hiding so position is preserved.
  Future<void> hideWindow() async {
    await saveWindowState();
    await windowManager.hide();
    _isVisible = false;
    onVisibilityChanged?.call();
    debugPrint('WindowService: Window hidden');
  }

  /// ── Minimize Window ───────────────────────────────────────────────────────
  Future<void> minimizeWindow() async {
    await windowManager.minimize();
  }

  /// ── Hide to Tray ──────────────────────────────────────────────────────────
  /// Hides the window to the system tray (alias for hideWindow for clarity).
  Future<void> hideToTray() async {
    await hideWindow();
  }

  /// ── Force Close Window ────────────────────────────────────────────────────
  /// Actually closes the app (bypasses prevent-close). Called when user
  /// selects "Quit" from the tray menu.
  Future<void> forceClose() async {
    await saveWindowState();
    _preventClose = false;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// ── Close Window ──────────────────────────────────────────────────────────
  /// Default close behavior: hides to tray instead of quitting.
  /// Use [forceClose] to actually terminate the application.
  Future<void> closeWindow() async {
    if (_preventClose) {
      await hideToTray();
      onCloseIntercepted?.call();
    } else {
      await forceClose();
    }
  }

  /// ── Bring to Front ────────────────────────────────────────────────────────
  /// Ensures the window is visible, restored (not minimized), and focused.
  Future<void> bringToFront() async {
    final isMinimized = await windowManager.isMinimized();
    if (isMinimized) {
      await windowManager.restore();
    }
    if (!_isVisible) {
      await showWindow();
    } else {
      await windowManager.focus();
    }
  }

  Future<void> setPosition(Offset position) async {
    await windowManager.setPosition(position);
  }

  Future<void> setSize(Size size) async {
    await windowManager.setSize(size);
  }

  Future<Offset> getPosition() async {
    return windowManager.getPosition();
  }

  Future<Size> getSize() async {
    return windowManager.getSize();
  }

  Future<void> setOpacity(double opacity) async {
    await windowManager.setOpacity(opacity.clamp(0.2, 1.0));
  }

  // ── WindowListener Overrides ─────────────────────────────────────────────

  @override
  void onWindowMoved() {
    saveWindowState();
  }

  @override
  void onWindowResized() {
    saveWindowState();
  }

  /// ── Intercept Close Event ─────────────────────────────────────────────────
  /// When prevent-close is enabled, the window hides to tray instead of
  /// closing. This keeps the app running in the background.
  @override
  void onWindowClose() async {
    if (_preventClose) {
      debugPrint('WindowService: Close intercepted — hiding to tray');
      await hideToTray();
      onCloseIntercepted?.call();
    } else {
      await saveWindowState();
      windowManager.removeListener(this);
      await windowManager.destroy();
    }
  }

  /// Cleanup when the service is disposed.
  void dispose() {
    windowManager.removeListener(this);
  }
}
