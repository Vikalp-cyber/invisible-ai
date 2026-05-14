import 'dart:async';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/app_constants.dart';
import 'backend_app_update_client.dart';

/// WinSparkle ([auto_updater]) for **background** checks + this service’s
/// **manual** “Check for updates” which uses the backend public API
/// (`GET /api/app-updates/check`, download, optional SHA-256 verify, RunAs installer).
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

  /// Manual “Check for updates”: backend [GET /api/app-updates/check], optional
  /// download + SHA-256 verify, then elevated installer.
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
    final nav = Navigator.of(context, rootNavigator: true);
    var loaderVisible = false;

    void closeLoader() {
      if (loaderVisible && context.mounted) {
        loaderVisible = false;
        nav.pop();
      }
    }

    try {
      loaderVisible = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            content: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('Checking for updates…')),
              ],
            ),
          ),
        ),
      );

      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;
      final client = BackendAppUpdateClient();
      final result = await client.check(currentVersion: current);

      closeLoader();

      if (!context.mounted) {
        return;
      }

      if (!result.updateAvailable || result.latest == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('You’re on the latest version ($current).'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final latest = result.latest!;

      final wantDownload = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update available: ${latest.version}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You have $current. Latest: ${result.latestVersion ?? latest.version}.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  if (latest.fileSize > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${(latest.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Release notes', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: MarkdownBody(
                      data: latest.releaseNotes?.trim().isNotEmpty == true
                          ? latest.releaseNotes!
                          : '_No release notes._',
                      shrinkWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Download'),
            ),
          ],
        ),
      );

      if (wantDownload != true || !context.mounted) {
        return;
      }

      loaderVisible = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text('Downloading installer…')),
              ],
            ),
          ),
        ),
      );

      Directory? tmpDir;
      try {
        tmpDir = await Directory.systemTemp.createTemp('flowdesk_update_');
        final safeName = latest.fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final file = File('${tmpDir.path}/$safeName');
        final uri = latest.downloadPath.trim().isNotEmpty
            ? client.downloadUri(latest.downloadPath)
            : client.latestDownloadUri;
        await client.downloadToFile(
          uri: uri,
          targetFile: file,
          expectedSha256: latest.sha256.trim().isNotEmpty ? latest.sha256 : null,
        );
        closeLoader();

        if (!context.mounted) {
          return;
        }

        await _launchInstallerElevated(file.path);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Installer started. Follow the prompts to complete the update.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        final dirToClean = tmpDir;
        unawaited(
          Future<void>.delayed(const Duration(minutes: 3), () async {
            try {
              if (await dirToClean.exists()) {
                await dirToClean.delete(recursive: true);
              }
            } catch (_) {}
          }),
        );
      } catch (e) {
        closeLoader();
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Download or install failed: $e'),
              duration: const Duration(seconds: 8),
            ),
          );
        }
        try {
          await tmpDir?.delete(recursive: true);
        } catch (_) {}
      }
    } catch (e) {
      closeLoader();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not check for updates: $e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  static Future<void> _launchInstallerElevated(String exePath) async {
    final psPath = exePath.replaceAll("'", "''");
    final r = await Process.run(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-WindowStyle',
        'Hidden',
        '-Command',
        "Start-Process -LiteralPath '$psPath' -Verb RunAs",
      ],
    );
    if (r.exitCode != 0) {
      final err = '${r.stderr}'.trim();
      throw StateError(
        err.isEmpty
            ? 'Installer did not start (exit code ${r.exitCode}).'
            : err,
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
