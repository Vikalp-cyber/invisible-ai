import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/auth_exception.dart';
import '../../domain/models/auth_user.dart';
import '../models/browser_oauth_callback.dart';
import '../models/desktop_oauth_config.dart';

class BrowserOAuthService {
  static const _stateAlphabet = '0123456789abcdef';

  final DesktopOAuthConfig _config;
  
  final List<HttpServer> _activeServers = [];
  final List<StreamSubscription<HttpRequest>> _activeSubscriptions = [];
  Completer<BrowserOAuthCallback>? _activeCompleter;

  BrowserOAuthService(this._config);

  Future<void> cancel() async {
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(
        const AuthException('Login cancelled by user.', code: 'cancelled'),
      );
    }
    _activeCompleter = null;

    for (final subscription in _activeSubscriptions) {
      await subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final server in _activeServers) {
      await server.close(force: true);
    }
    _activeServers.clear();
  }

  Future<BrowserOAuthCallback> signInWithGoogle() async {
    await cancel();
    
    final servers = await _bindServers();
    _activeServers.addAll(servers);
    
    final completer = Completer<BrowserOAuthCallback>();
    _activeCompleter = completer;

    try {
      for (final server in servers) {
        _activeSubscriptions.add(
          server.listen(
            (request) => _handleRequest(request, completer),
            onError: (Object error, StackTrace stackTrace) {
              if (!completer.isCompleted) {
                completer.completeError(
                  AuthException(
                    'The localhost callback listener failed: $error',
                  ),
                  stackTrace,
                );
              }
            },
          ),
        );
      }

      // The backend decides the final desktop callback URL via
      // DESKTOP_CALLBACK_URL, so the desktop client only needs to open the
      // authorize endpoint and optionally send a CSRF state token.
      final launched = await launchUrl(
        _config.buildGoogleAuthUri(state: _createOAuthState()),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const AuthException(
          'Could not open the browser for Google sign-in.',
        );
      }

      return await completer.future.timeout(
        _config.loginTimeout,
        onTimeout: () {
          throw const AuthException(
            'Google sign-in was cancelled or timed out before the callback arrived.',
            code: 'timeout',
          );
        },
      );
    } finally {
      await cancel();
    }
  }

  Future<List<HttpServer>> _bindServers() async {
    final servers = <HttpServer>[
      await HttpServer.bind(InternetAddress.loopbackIPv4, _config.callbackPort),
    ];

    try {
      servers.add(
        await HttpServer.bind(
          InternetAddress.loopbackIPv6,
          _config.callbackPort,
          v6Only: true,
        ),
      );
    } on SocketException {
      // IPv6 is optional here; IPv4 loopback covers the common Windows case.
    }

    return servers;
  }

  Future<void> _handleRequest(
    HttpRequest request,
    Completer<BrowserOAuthCallback> completer,
  ) async {
    final response = request.response;
    response.headers
      ..contentType = ContentType.html
      ..set(HttpHeaders.cacheControlHeader, 'no-store');

    try {
      if (!_config.matchesCallbackPath(request.uri.path)) {
        response.statusCode = HttpStatus.notFound;
        response.write('<h1>Not Found</h1>');
        return;
      }

      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.write('<h1>Method Not Allowed</h1>');
        return;
      }

      final params = request.uri.queryParameters;
      final errorMessage = _firstNonEmpty(params, const [
        'error_description',
        'message',
        'error',
      ]);

      if (errorMessage != null) {
        response.write(_errorPage('Google sign-in failed: $errorMessage'));
        if (!completer.isCompleted) {
          completer.completeError(
            AuthException('Google sign-in failed: $errorMessage'),
          );
        }
        return;
      }

      final accessToken = _firstNonEmpty(params, [
        _config.accessTokenParam,
        'access_token',
        'token',
      ]);
      final refreshToken = _firstNonEmpty(params, [
        _config.refreshTokenParam,
        'refresh_token',
      ]);

      if (accessToken == null && refreshToken == null && params.isEmpty) {
        response.write(_fragmentRelayPage());
        return;
      }

      if (accessToken == null || refreshToken == null) {
        response.statusCode = HttpStatus.badRequest;
        response.write(
          _errorPage(
            'The login callback did not include both access and refresh tokens.',
          ),
        );
        if (!completer.isCompleted) {
          completer.completeError(
            const AuthException(
              'The login callback did not include both access and refresh tokens.',
            ),
          );
        }
        return;
      }

      response.write(_successPage());
      if (!completer.isCompleted) {
        completer.complete(
          BrowserOAuthCallback(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: _extractUser(params),
          ),
        );
      }
    } catch (error, stackTrace) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(
        _errorPage('The desktop login callback could not be read.'),
      );
      if (!completer.isCompleted) {
        completer.completeError(
          AuthException('Could not process the desktop login callback: $error'),
          stackTrace,
        );
      }
    } finally {
      await response.close();
    }
  }

  AuthUser? _extractUser(Map<String, String> params) {
    final rawUser = _firstNonEmpty(params, [
      _config.userParam,
      'profile',
      'userJson',
    ]);
    if (rawUser != null) {
      final parsed = _tryParseUserJson(rawUser);
      if (parsed != null && parsed.isResolved) {
        return parsed;
      }
    }

    final user = AuthUser.fromJson({
      'id': _firstNonEmpty(params, const ['userId', 'id', 'sub']),
      'email': _firstNonEmpty(params, const ['email']),
      'displayName': _firstNonEmpty(params, const ['displayName', 'name']),
      'photoUrl': _firstNonEmpty(params, const [
        'photoUrl',
        'avatarUrl',
        'picture',
      ]),
    });

    return user.isResolved ? user : null;
  }

  AuthUser? _tryParseUserJson(String rawUser) {
    final direct = _tryDecodeUserMap(rawUser);
    if (direct != null) {
      return AuthUser.fromJson(direct);
    }

    final decoded = _tryDecodeUserMap(Uri.decodeComponent(rawUser));
    if (decoded != null) {
      return AuthUser.fromJson(decoded);
    }

    try {
      final normalized = base64Url.normalize(rawUser);
      final jsonString = utf8.decode(base64Url.decode(normalized));
      final userMap = _tryDecodeUserMap(jsonString);
      if (userMap != null) {
        return AuthUser.fromJson(userMap);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _tryDecodeUserMap(String rawUser) {
    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _firstNonEmpty(Map<String, String> params, List<String> keys) {
    for (final key in keys) {
      final value = params[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _createOAuthState() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 32; index++) {
      buffer.write(_stateAlphabet[random.nextInt(_stateAlphabet.length)]);
    }
    return buffer.toString();
  }

  String _successPage() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Login Complete</title>
    <style>
      body { font-family: Segoe UI, sans-serif; background: #0d1117; color: #f0f6fc; display: grid; place-items: center; min-height: 100vh; margin: 0; }
      .card { max-width: 440px; padding: 24px; border-radius: 16px; background: #161b22; border: 1px solid #30363d; text-align: center; }
      h1 { margin-top: 0; font-size: 24px; }
      p { color: #9da7b3; line-height: 1.5; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Signed in</h1>
      <p>You can close this browser window and return to the desktop app.</p>
    </div>
  </body>
</html>
''';
  }

  String _errorPage(String message) {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Login Failed</title>
    <style>
      body { font-family: Segoe UI, sans-serif; background: #0d1117; color: #f0f6fc; display: grid; place-items: center; min-height: 100vh; margin: 0; }
      .card { max-width: 460px; padding: 24px; border-radius: 16px; background: #161b22; border: 1px solid #30363d; text-align: center; }
      h1 { margin-top: 0; font-size: 24px; color: #ff7b72; }
      p { color: #9da7b3; line-height: 1.5; }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Login failed</h1>
      <p>$message</p>
      <p>You can close this window and try again from the app.</p>
    </div>
  </body>
</html>
''';
  }

  String _fragmentRelayPage() {
    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Completing Sign-In</title>
    <style>
      body { font-family: Segoe UI, sans-serif; background: #0d1117; color: #f0f6fc; display: grid; place-items: center; min-height: 100vh; margin: 0; }
      .card { max-width: 460px; padding: 24px; border-radius: 16px; background: #161b22; border: 1px solid #30363d; text-align: center; }
      p { color: #9da7b3; line-height: 1.5; }
    </style>
  </head>
  <body>
    <div class="card">
      <p>Completing your sign-in...</p>
      <p>If this page does not close automatically, return to the desktop app and try again.</p>
    </div>
    <script>
      const hash = window.location.hash.startsWith('#') ? window.location.hash.substring(1) : '';
      if (hash) {
        const nextUrl = window.location.pathname + '?' + hash;
        window.location.replace(nextUrl);
      }
    </script>
  </body>
</html>
''';
  }
}
