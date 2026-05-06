import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// ── Tray Service ───────────────────────────────────────────────────────────
/// Manages the system tray icon, tooltip, and right-click context menu.
/// Handles tray interactions like showing/hiding the window and quitting.
///
/// The tray icon provides persistent access to the app when the window is
/// hidden, allowing users to restore it or fully exit.
class TrayService with TrayListener {
  /// Callback to show the overlay window.
  final VoidCallback? onShowWindow;

  /// Callback to start a new chat.
  final VoidCallback? onNewChat;

  /// Callback to toggle always-on-top.
  final VoidCallback? onToggleAlwaysOnTop;

  /// Callback for full application exit.
  final VoidCallback? onQuit;

  TrayService({
    this.onShowWindow,
    this.onNewChat,
    this.onToggleAlwaysOnTop,
    this.onQuit,
  });

  /// ── Initialize System Tray ────────────────────────────────────────────────
  /// Sets the tray icon, tooltip, and context menu. Registers this service
  /// as a listener for tray events (click, menu selection).
  Future<void> init() async {
    // Add this service as a tray event listener.
    trayManager.addListener(this);

    // Set the tray icon — use .ico on Windows, .png elsewhere.
    final iconPath = Platform.isWindows
        ? AppConstants.trayIconWindows
        : AppConstants.trayIconDefault;

    await trayManager.setIcon(iconPath);

    // Set the tooltip shown on hover.
    await trayManager.setToolTip(AppConstants.trayTooltip);

    // Build and set the right-click context menu.
    await _setupContextMenu();

    debugPrint('TrayService: System tray initialized');
  }

  /// ── Setup Context Menu ────────────────────────────────────────────────────
  /// Creates the right-click tray menu with the following items:
  ///   - Show Invisible AI
  ///   - New Chat
  ///   - Toggle Always on Top
  ///   - ─── (separator)
  ///   - Quit
  Future<void> _setupContextMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: AppStrings.trayShowWindow,
        ),
        MenuItem(
          key: 'new_chat',
          label: AppStrings.trayNewChat,
        ),
        MenuItem(
          key: 'toggle_always_on_top',
          label: AppStrings.trayToggleAlwaysOnTop,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: AppStrings.trayQuit,
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  // ── TrayListener Overrides ──────────────────────────────────────────────

  /// Single click on the tray icon: show the overlay window.
  @override
  void onTrayIconMouseDown() {
    debugPrint('TrayService: Tray icon clicked — showing window');
    onShowWindow?.call();
  }

  /// Right click on the tray icon: show the context menu.
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// Handle context menu item selection.
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('TrayService: Menu item clicked: ${menuItem.key}');

    switch (menuItem.key) {
      case 'show_window':
        onShowWindow?.call();
        break;
      case 'new_chat':
        onNewChat?.call();
        break;
      case 'toggle_always_on_top':
        onToggleAlwaysOnTop?.call();
        break;
      case 'quit':
        onQuit?.call();
        break;
    }
  }

  /// ── Cleanup ───────────────────────────────────────────────────────────────
  /// Removes the tray listener and destroys the tray icon.
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    debugPrint('TrayService: Tray destroyed');
  }
}
