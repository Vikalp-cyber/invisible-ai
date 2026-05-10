import 'dart:async';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

/// WinSparkle ([auto_updater]) wiring: appcast feed, periodic checks, logging.
///
/// Requires [dsa_pub.pem] embedded in `windows/runner/Runner.rc` and an HTTPS
/// appcast URL that matches signatures from `dart run auto_updater:sign_update`.
class AppUpdateService with UpdaterListener {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _initialized = false;

  static bool get isSupported => Platform.isWindows;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> initializeIfSupported() async {
    if (!isSupported || _initialized) {
      return;
    }
    _initialized = true;
    autoUpdater.addListener(this);

    try {
      await autoUpdater.setFeedURL(AppConstants.windowsAppcastUrl);
      await autoUpdater.setScheduledCheckInterval(
        AppConstants.windowsUpdateCheckIntervalSeconds,
      );
      await autoUpdater.checkForUpdates(inBackground: true);
    } catch (e, st) {
      debugPrint('AppUpdateService: initialization failed: $e\n$st');
    }
  }

  /// Shows the WinSparkle UI when [inBackground] is false.
  Future<void> checkForUpdates({required bool inBackground}) async {
    if (!isSupported) {
      return;
    }
    if (!_initialized) {
      await initializeIfSupported();
    }
    try {
      await autoUpdater.checkForUpdates(inBackground: inBackground);
    } catch (e, st) {
      debugPrint('AppUpdateService: checkForUpdates failed: $e\n$st');
      rethrow;
    }
  }

  /// Manual “Check for updates” from UI: native WinSparkle dialog + snackbar on failure.
  static Future<void> presentManualCheck(BuildContext context) async {
    if (!isSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updates are only available on Windows.')),
        );
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final listener = _SnackBarFeedbackListener(
      messenger: messenger,
      context: context,
    );
    autoUpdater.addListener(listener);

    try {
      await instance.checkForUpdates(inBackground: false);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not start update check: $e')),
        );
      }
    } finally {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 20), () {
          autoUpdater.removeListener(listener);
        }),
      );
    }
  }

  @override
  void onUpdaterError(UpdaterError? error) {
    if (error != null) {
      debugPrint('AppUpdateService error: ${error.message}');
    }
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    if (error != null) {
      debugPrint('AppUpdateService: update check finished with error: ${error.message}');
    }
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {}

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {}
}

class _SnackBarFeedbackListener with UpdaterListener {
  _SnackBarFeedbackListener({
    required this.messenger,
    required this.context,
  });

  final ScaffoldMessengerState messenger;
  final BuildContext context;
  bool _showedUpToDate = false;

  @override
  void onUpdaterError(UpdaterError? error) {
    if (error == null || !context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Update server unreachable or appcast invalid: ${error.message}',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update check failed: ${error.message}'),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (_showedUpToDate) {
      return;
    }
    _showedUpToDate = true;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('You are on the latest version.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {}

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {}
}
