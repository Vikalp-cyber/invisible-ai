import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/models/desktop_oauth_config.dart';

/// Public `GET /api/app-updates/*` client (no auth). Uses the same [DesktopOAuthConfig.baseUrl] as the rest of the app.
class BackendAppUpdateClient {
  BackendAppUpdateClient([DesktopOAuthConfig? config])
      : _config = config ?? DesktopOAuthConfig.fromEnvironment();

  final DesktopOAuthConfig _config;

  String get _root => _config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  Uri _apiUri(String pathAndQuery) {
    final p = pathAndQuery.startsWith('/') ? pathAndQuery : '/$pathAndQuery';
    return Uri.parse('$_root/api$p');
  }

  /// `GET /api/app-updates/check?currentVersion=…`
  Future<AppUpdateCheckResponse> check({required String currentVersion}) async {
    final uri = _apiUri('/app-updates/check').replace(
      queryParameters: <String, String>{'currentVersion': currentVersion},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode == 400) {
      throw AppUpdateApiException(
        response.statusCode,
        'Missing or invalid currentVersion.',
      );
    }
    if (response.statusCode != 200) {
      throw AppUpdateApiException(
        response.statusCode,
        response.body.isNotEmpty ? response.body : 'Update check failed.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON from app-updates/check');
    }
    return AppUpdateCheckResponse.fromJson(data);
  }

  /// Builds `GET {baseUrl}/api{downloadPath}` (e.g. `/app-updates/download/1.2.0`).
  Uri downloadUri(String downloadPath) {
    final p = downloadPath.trim();
    if (p.isEmpty) {
      throw ArgumentError('downloadPath is empty');
    }
    final suffix = p.startsWith('/') ? p : '/$p';
    return Uri.parse('$_root/api$suffix');
  }

  /// `GET /api/app-updates/latest/download`
  Uri get latestDownloadUri => _apiUri('/app-updates/latest/download');

  /// Streams installer to [targetFile]. Verifies body SHA-256 against [expectedSha256] when non-empty.
  /// Uses [X-SHA256] response header when [expectedSha256] is null/empty.
  Future<AppUpdateDownloadResult> downloadToFile({
    required Uri uri,
    required File targetFile,
    String? expectedSha256,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(minutes: 30));
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw AppUpdateApiException(
          streamed.statusCode,
          body.isNotEmpty ? body : 'Download failed (HTTP ${streamed.statusCode}).',
        );
      }
      final headerSha = _headerSha256(streamed.headers);
      final expect = (expectedSha256 ?? headerSha)?.trim();
      final sink = targetFile.openWrite();
      try {
        await streamed.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      if (expect != null && expect.isNotEmpty) {
        final digest = await sha256.bind(targetFile.openRead()).first;
        final actualHex = digest.toString();
        if (!_hexEquals(actualHex, expect)) {
          try {
            await targetFile.delete();
          } catch (_) {}
          throw AppUpdateChecksumException(expect, actualHex);
        }
      }
      return AppUpdateDownloadResult(
        file: targetFile,
        verifiedSha256: expect,
        contentLength: streamed.contentLength,
      );
    } finally {
      client.close();
    }
  }

  String? _headerSha256(Map<String, String> headers) {
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == 'x-sha256') {
        return e.value.trim();
      }
    }
    return null;
  }

  static bool _hexEquals(String a, String b) {
    return a.toLowerCase().replaceAll(RegExp(r'\s'), '') ==
        b.toLowerCase().replaceAll(RegExp(r'\s'), '');
  }
}

class AppUpdateApiException implements Exception {
  AppUpdateApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'AppUpdateApiException($statusCode): $message';
}

class AppUpdateChecksumException implements Exception {
  AppUpdateChecksumException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() =>
      'Downloaded file SHA-256 does not match. Expected $expected, got $actual.';
}

class AppLatestRelease {
  const AppLatestRelease({
    required this.version,
    required this.fileName,
    required this.fileSize,
    required this.sha256,
    required this.downloadPath,
    this.releaseNotes,
    this.releasedAt,
  });

  final String version;
  final String fileName;
  final int fileSize;
  final String sha256;
  final String downloadPath;
  final String? releaseNotes;
  final String? releasedAt;

  factory AppLatestRelease.fromJson(Map<String, dynamic> j) {
    final size = j['fileSize'];
    return AppLatestRelease(
      version: j['version'] as String? ?? '',
      fileName: j['fileName'] as String? ?? 'setup.exe',
      fileSize: size is int ? size : (size is num ? size.toInt() : 0),
      sha256: (j['sha256'] as String?)?.trim() ?? '',
      downloadPath: (j['downloadPath'] as String?)?.trim() ?? '',
      releaseNotes: j['releaseNotes'] as String?,
      releasedAt: j['releasedAt'] as String?,
    );
  }
}

class AppUpdateCheckResponse {
  const AppUpdateCheckResponse({
    required this.updateAvailable,
    required this.currentVersion,
    this.latestVersion,
    this.latest,
  });

  final bool updateAvailable;
  final String currentVersion;
  final String? latestVersion;
  final AppLatestRelease? latest;

  factory AppUpdateCheckResponse.fromJson(Map<String, dynamic> j) {
    AppLatestRelease? latest;
    final raw = j['latest'];
    if (raw is Map<String, dynamic>) {
      latest = AppLatestRelease.fromJson(raw);
    }
    return AppUpdateCheckResponse(
      updateAvailable: j['updateAvailable'] == true,
      currentVersion: j['currentVersion'] as String? ?? '',
      latestVersion: j['latestVersion'] as String?,
      latest: latest,
    );
  }
}

class AppUpdateDownloadResult {
  AppUpdateDownloadResult({
    required this.file,
    this.verifiedSha256,
    this.contentLength,
  });

  final File file;
  final String? verifiedSha256;
  final int? contentLength;
}
