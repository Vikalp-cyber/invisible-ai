import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// ── Hotkey Service ─────────────────────────────────────────────────────────
/// Manages global (system-wide) keyboard shortcuts. These shortcuts work even
/// when the app is hidden or unfocused, allowing the user to summon the
/// overlay from anywhere.
///
/// Default shortcuts:
///   - Ctrl+Shift+Space → Toggle overlay visibility
///   - Ctrl+Shift+N     → Start a new chat (show overlay + clear + focus)
///
/// Architecture note: This service is decoupled from UI — it accepts callback
/// functions that the provider layer wires up. This makes it testable and
/// allows easy reconfiguration of shortcuts in the future.
class HotkeyService {
  /// Callback invoked when the toggle overlay hotkey is pressed.
  final VoidCallback? onToggleOverlay;

  /// Callback invoked when the new chat hotkey is pressed.
  final VoidCallback? onNewChat;

  /// Registered hotkeys for cleanup.
  final List<HotKey> _registeredHotkeys = [];

  HotkeyService({this.onToggleOverlay, this.onNewChat});

  /// ── Initialize & Register All Hotkeys ────────────────────────────────────
  /// Must be called once at app startup after WidgetsFlutterBinding is
  /// initialized. Clears any stale registrations first (important for
  /// hot reload during development).
  Future<void> init() async {
    // Unregister all previous hotkeys to prevent duplicates on hot reload.
    await hotKeyManager.unregisterAll();

    // ── Toggle Overlay: Ctrl+Shift+Space ──────────────────────────────────
    await _registerHotkey(
      key: PhysicalKeyboardKey.space,
      modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      label: 'Toggle Overlay',
      handler: onToggleOverlay,
    );

    // ── New Chat: Ctrl+Shift+N ────────────────────────────────────────────
    await _registerHotkey(
      key: PhysicalKeyboardKey.keyN,
      modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      label: 'New Chat',
      handler: onNewChat,
    );
  }

  /// ── Register a Single Hotkey ─────────────────────────────────────────────
  /// Creates and registers a global (system-scope) hotkey with the given
  /// physical key and modifiers. The [handler] callback is invoked on keyDown.
  Future<void> _registerHotkey({
    required PhysicalKeyboardKey key,
    required List<HotKeyModifier> modifiers,
    required String label,
    VoidCallback? handler,
  }) async {
    final hotKey = HotKey(
      key: key,
      modifiers: modifiers,
      scope: HotKeyScope.system, // Global — works even when app is unfocused.
    );

    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          debugPrint('HotkeyService: $label triggered');
          handler?.call();
        },
      );

      _registeredHotkeys.add(hotKey);
      debugPrint('HotkeyService: Registered $label hotkey');
    } catch (e) {
      debugPrint('HotkeyService: Failed to register $label hotkey: $e');
    }
  }

  /// ── Unregister All Hotkeys ───────────────────────────────────────────────
  /// Should be called when the app is shutting down to release OS resources.
  Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
      _registeredHotkeys.clear();
      debugPrint('HotkeyService: All hotkeys unregistered');
    } catch (e) {
      debugPrint('HotkeyService: Failed to unregister hotkeys: $e');
    }
  }
}
