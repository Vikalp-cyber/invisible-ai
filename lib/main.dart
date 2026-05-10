import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'services/app_update_service.dart';
import 'services/preference_service.dart';
import 'services/secure_storage_service.dart';
import 'services/hotkey_service.dart';
import 'services/tray_service.dart';
import 'services/overlay_protection_manager.dart';
import 'features/assistant/presentation/providers/assistant_provider.dart';
import 'features/overlay/presentation/providers/overlay_provider.dart';

/// ── Application Entry Point ────────────────────────────────────────────────
/// Initializes (in order):
/// 1. Flutter bindings
/// 2. Single-instance check (via lock file)
/// 3. SharedPreferences service
/// 4. window_manager — frameless, transparent, always-on-top configuration
/// 5. Riverpod ProviderScope wrapping the app
/// 6. Global hotkey registration (Ctrl+Shift+Space, Ctrl+Shift+N)
/// 7. System tray setup (icon, context menu)
///
/// The window starts hidden (bitsdojo_window hides it on startup) and is
/// revealed after Flutter is ready to render, preventing visual flicker.

/// Lock file used to prevent multiple instances.
File? _lockFile;
RandomAccessFile? _lockFileHandle;

void main() async {
  // Ensure Flutter bindings are initialized before calling platform APIs.
  WidgetsFlutterBinding.ensureInitialized();

  // ── Single-Instance Check ───────────────────────────────────────────────
  // Use a lock file to prevent multiple instances from running.
  if (!await _acquireSingleInstanceLock()) {
    debugPrint('Another instance is already running. Exiting.');
    exit(0);
  }

  await AppUpdateService.instance.initializeIfSupported();

  // ── Initialize Preferences & Storage ─────────────────────────────────────
  // Must be initialized before WindowService reads persisted state.
  final preferenceService = PreferenceService();
  await preferenceService.init();

  final secureStorageService = SecureStorageService();

  // ── Initialize Window Manager ───────────────────────────────────────────
  await windowManager.ensureInitialized();

  // Configure the window with desired properties.
  final windowOptions = WindowOptions(
    size: AppConstants.defaultWindowSize,
    minimumSize: AppConstants.minimumWindowSize,
    maximumSize: AppConstants.maximumWindowSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  // Wait for the window to be ready, then configure and show it.
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    // Enable close interception — close hides to tray instead of quitting.
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  // ── Apply Native Screen Capture Protection ──────────────────────────────
  final overlayProtectionManager = OverlayProtectionManager();
  await overlayProtectionManager.initialize(
    autoApplyOnStartup: true,
    startupEnabled: true,
  );

  // Release the native Win32 hide lock applied by bitsdojo_window in main.cpp
  doWhenWindowReady(() {
    appWindow.show();
  });

  // ── Create the Riverpod Container ─────────────────────────────────────
  // We need a ProviderContainer to resolve the AssistantNotifier for
  // wiring up hotkey and tray callbacks before the widget tree builds.
  final container = ProviderContainer(
    overrides: [
      preferenceServiceProvider.overrideWithValue(preferenceService),
      secureStorageServiceProvider.overrideWithValue(secureStorageService),
    ],
  );

  // Initialize overlay orchestration/layout engine before first frame.
  await container.read(overlayProvider.notifier).initializeSmartLayout();

  // ── Initialize Hotkey Service ───────────────────────────────────────────
  // Register global keyboard shortcuts that work even when the app is
  // hidden or unfocused.
  final hotkeyService = HotkeyService(
    onToggleOverlay: () {
      container.read(assistantProvider.notifier).toggleOverlayVisibility();
    },
    onNewChat: () {
      container.read(assistantProvider.notifier).newChat();
    },
  );
  await hotkeyService.init();

  // ── Initialize Tray Service ─────────────────────────────────────────────
  // Set up the system tray icon with context menu for showing/hiding the
  // overlay and quitting the app.
  late final TrayService trayService;
  trayService = TrayService(
    onShowWindow: () {
      container.read(assistantProvider.notifier).showOverlay();
    },
    onNewChat: () {
      container.read(assistantProvider.notifier).newChat();
    },
    onToggleAlwaysOnTop: () {
      container.read(assistantProvider.notifier).toggleAlwaysOnTop();
    },
    onQuit: () async {
      // Cleanup services before quitting.
      await hotkeyService.dispose();
      await trayService.dispose();
      _releaseSingleInstanceLock();
      await container.read(assistantProvider.notifier).forceQuit();
    },
  );
  await trayService.init();

  // ── Launch App ──────────────────────────────────────────────────────────
  // Use UncontrolledProviderScope to share the existing container with
  // the widget tree (since we already created providers above).
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const InvisibleAIApp(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Single-Instance Lock (File-Based) ───────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/// Attempts to acquire an exclusive file lock. If another process already
/// holds the lock, this instance should exit.
///
/// Uses a file in the user's temp directory with an exclusive lock.
/// Returns true if this is the first instance, false otherwise.
Future<bool> _acquireSingleInstanceLock() async {
  try {
    final lockPath =
        '${Directory.systemTemp.path}/'
        '${AppConstants.singleInstanceMutex}.lock';
    _lockFile = File(lockPath);
    _lockFileHandle = await _lockFile!.open(mode: FileMode.write);
    await _lockFileHandle!.lock(FileLock.exclusive);
    // Write PID so we can identify the owning process.
    await _lockFileHandle!.writeString('$pid');
    return true;
  } catch (e) {
    debugPrint(
      'SingleInstance: Lock acquisition failed (another instance?): $e',
    );
    return false;
  }
}

/// Releases the single-instance lock file.
void _releaseSingleInstanceLock() {
  try {
    _lockFileHandle?.unlockSync();
    _lockFileHandle?.closeSync();
    _lockFile?.deleteSync();
  } catch (_) {
    // Best effort cleanup.
  }
}
