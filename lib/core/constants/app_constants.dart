import 'package:flutter/material.dart';

/// ── App Constants ──────────────────────────────────────────────────────────
/// Centralized configuration values for window sizing, animation durations,
/// and SharedPreferences keys. Keeps magic numbers out of widget code.
class AppConstants {
  AppConstants._();

  // ── Window Defaults ────────────────────────────────────────────────────────
  /// Default window dimensions.
  static const Size defaultWindowSize = Size(800, 600);

  /// Minimum allowed window size to prevent content from breaking.
  static const Size minimumWindowSize = Size(800, 600);

  /// Maximum window size cap.
  static const Size maximumWindowSize = Size(1200, 900);

  // ── Border Radius ──────────────────────────────────────────────────────────
  /// Main window corner radius for the floating panel look.
  static const double windowBorderRadius = 16.0;

  /// Card / container corner radius.
  static const double cardBorderRadius = 12.0;

  /// Small element (buttons, chips) corner radius.
  static const double smallBorderRadius = 8.0;

  /// Input field corner radius.
  static const double inputBorderRadius = 24.0;

  // ── Glassmorphism ──────────────────────────────────────────────────────────
  /// Backdrop blur sigma for the glass effect.
  static const double blurSigma = 20.0;

  /// Glass surface opacity (white channel).
  static const double glassSurfaceOpacity = 0.06;

  /// Glass border opacity.
  static const double glassBorderOpacity = 0.15;

  // ── Animation Durations ────────────────────────────────────────────────────
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 350);
  static const Duration slowAnimation = Duration(milliseconds: 600);
  static const Duration messageEntryAnimation = Duration(milliseconds: 450);

  // ── Layout ─────────────────────────────────────────────────────────────────
  /// Height of the custom draggable title bar.
  static const double titleBarHeight = 48.0;

  /// Height of the action buttons row.
  static const double actionBarHeight = 44.0;

  /// Height of the input text area.
  static const double inputAreaHeight = 64.0;

  /// Standard horizontal padding for content.
  static const double horizontalPadding = 16.0;

  /// Standard vertical gap between sections.
  static const double sectionGap = 8.0;

  // ── SharedPreferences Keys ─────────────────────────────────────────────────
  static const String keyWindowX = 'window_x';
  static const String keyWindowY = 'window_y';
  static const String keyWindowWidth = 'window_width';
  static const String keyWindowHeight = 'window_height';
  static const String keyAlwaysOnTop = 'always_on_top';
  static const String keyMinimizeToTray = 'minimize_to_tray';
  static const String keyOverlayVisible = 'overlay_visible';
  static const String keyOverlayWorkspaceState = 'overlay_workspace_state';
  static const String keyOverlayMode = 'overlay_mode';
  static const String keyOverlayAutoHide = 'overlay_auto_hide';
  static const String keyOverlayExpanded = 'overlay_expanded';
  static const String keyOverlayDockEdge = 'overlay_dock_edge';
  static const String keyOverlayOpacity = 'overlay_opacity';

  /// Persisted Groq model id only (never the API key).
  static const String keyGroqModelId = 'groq_model_id';

  /// Premium unlocked after successful Razorpay verification (local hint only).
  static const String keyPremiumActive = 'premium_active';

  /// ISO-8601 timestamp of last successful payment verification.
  static const String keyPremiumVerifiedAt = 'premium_verified_at';

  /// `POST /api/payments/create-link` body field (must match `GET /api/pricing/plans`).
  static const String premiumPlanType = 'lifetime';

  /// Poll `GET /api/subscription/status` while user pays in the browser.
  static const Duration subscriptionPollInterval = Duration(seconds: 5);

  /// Stop polling after this duration (user may still complete payment later).
  static const Duration subscriptionPollTimeout = Duration(minutes: 5);

  // ── AI Mock Delay ──────────────────────────────────────────────────────────
  /// Simulated AI thinking time range.
  static const Duration mockMinDelay = Duration(milliseconds: 800);
  static const Duration mockMaxDelay = Duration(milliseconds: 2000);

  // ── Global Hotkey Defaults ─────────────────────────────────────────────────
  /// Default hotkey: Ctrl+Shift+Space to toggle overlay visibility.
  /// These are the default values; users can reconfigure in the future.
  static const String defaultToggleHotkeyDisplay = 'Ctrl+Shift+Space';
  static const String defaultNewChatHotkeyDisplay = 'Ctrl+Shift+N';

  // ── Overlay Animations ─────────────────────────────────────────────────────
  /// Duration for the overlay show/hide transition.
  static const Duration overlayShowDuration = Duration(milliseconds: 300);
  static const Duration overlayHideDuration = Duration(milliseconds: 200);
  static const Duration autoHideDelay = Duration(milliseconds: 1200);

  static const Size compactWindowSize = Size(320, 420);
  static const Size focusWindowSize = Size(460, 680);

  // ── Tray ────────────────────────────────────────────────────────────────────
  /// Tray icon asset paths.
  static const String trayIconWindows = 'assets/app_icon.ico';
  static const String trayIconDefault = 'assets/app_icon.png';
  static const String trayTooltip = 'Flowdesk';

  // ── Single Instance ────────────────────────────────────────────────────────
  /// Mutex name used to prevent multiple app instances.
  static const String singleInstanceMutex = 'FlowdeskSingletonMutex';

  // ── Windows auto-updater ─────────────────────────────────────────────────
  /// WinSparkle background feed (RSS). Manual **Check for updates** uses the
  /// backend public API: `GET /api/app-updates/check` (see [AppUpdateService]).
  static const String windowsAppcastUrl =
      'https://raw.githubusercontent.com/LuminoAi/invisible-ai/main/docs/appcast-win.xml';

  /// Seconds between background checks (WinSparkle minimum is 3600).
  static const int windowsUpdateCheckIntervalSeconds = 86400;
}
