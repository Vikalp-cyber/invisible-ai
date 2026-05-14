class DesktopOAuthConfig {
  final String baseUrl;
  final String googleAuthPath;
  final String refreshPath;
  final String mePath;
  final String logoutPath;
  /// Authenticated (user access token) endpoint returning resolved Groq + optional
  /// Deepgram keys (`GET /api/client-config`). Same Bearer as other user routes.
  ///
  /// Legacy shape (Groq only, flat JSON): set [clientConfigPath] to `/api/groq/client-config`
  /// or compile with `GROQ_CLIENT_CONFIG_PATH` (used when `CLIENT_CONFIG_PATH` is unset).
  ///
  /// Not the admin `/api/admin/groq-keys` API — that must never ship in the client.
  final String clientConfigPath;
  final String accessTokenParam;
  final String refreshTokenParam;
  final String userParam;
  final String callbackHost;
  final int callbackPort;
  final String callbackPath;
  final Duration loginTimeout;
  final Duration tokenRefreshSkew;

  const DesktopOAuthConfig({
    required this.baseUrl,
    required this.googleAuthPath,
    required this.refreshPath,
    required this.mePath,
    required this.logoutPath,
    required this.clientConfigPath,
    required this.accessTokenParam,
    required this.refreshTokenParam,
    required this.userParam,
    required this.callbackHost,
    required this.callbackPort,
    required this.callbackPath,
    required this.loginTimeout,
    required this.tokenRefreshSkew,
  });

  factory DesktopOAuthConfig.fromEnvironment() {
    const clientPathEnv = String.fromEnvironment('CLIENT_CONFIG_PATH');
    const legacyGroqPathEnv = String.fromEnvironment('GROQ_CLIENT_CONFIG_PATH');
    final resolvedClientConfigPath = clientPathEnv.isNotEmpty
        ? clientPathEnv
        : (legacyGroqPathEnv.isNotEmpty
              ? legacyGroqPathEnv
              : '/api/client-config');

    return DesktopOAuthConfig(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://flowdesk-backend.luminoai.online',
      ),
      googleAuthPath: const String.fromEnvironment(
        'AUTH_GOOGLE_PATH',
        defaultValue: '/api/auth/google',
      ),
      refreshPath: const String.fromEnvironment(
        'AUTH_REFRESH_PATH',
        defaultValue: '/api/auth/refresh',
      ),
      mePath: const String.fromEnvironment(
        'AUTH_ME_PATH',
        defaultValue: '/api/auth/me',
      ),
      logoutPath: const String.fromEnvironment('AUTH_LOGOUT_PATH', defaultValue: ''),
      clientConfigPath: resolvedClientConfigPath,
      accessTokenParam: String.fromEnvironment(
        'AUTH_ACCESS_TOKEN_PARAM',
        defaultValue: 'accessToken',
      ),
      refreshTokenParam: String.fromEnvironment(
        'AUTH_REFRESH_TOKEN_PARAM',
        defaultValue: 'refreshToken',
      ),
      userParam: String.fromEnvironment(
        'AUTH_USER_PARAM',
        defaultValue: 'user',
      ),
      callbackHost: String.fromEnvironment(
        'AUTH_CALLBACK_HOST',
        defaultValue: 'flowdesk-backend.luminoai.online',
      ),
      callbackPort: int.fromEnvironment(
        'AUTH_CALLBACK_PORT',
        defaultValue: 45872,
      ),
      callbackPath: String.fromEnvironment(
        'AUTH_CALLBACK_PATH',
        defaultValue: '/callback',
      ),
      loginTimeout: Duration(
        seconds: int.fromEnvironment(
          'AUTH_LOGIN_TIMEOUT_SECONDS',
          defaultValue: 180,
        ),
      ),
      tokenRefreshSkew: Duration(
        seconds: int.fromEnvironment(
          'AUTH_TOKEN_REFRESH_SKEW_SECONDS',
          defaultValue: 60,
        ),
      ),
    );
  }

  Uri get callbackUri => Uri(
    scheme: 'http',
    host: callbackHost,
    port: callbackPort,
    path: normalizedCallbackPath,
  );

  Uri get googleAuthUri => buildGoogleAuthUri();

  Uri buildGoogleAuthUri({String? state}) {
    final uri = resolve(googleAuthPath);
    final normalizedState = state?.trim();
    if (normalizedState == null || normalizedState.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'state': normalizedState,
      },
    );
  }

  String get normalizedCallbackPath => _normalizePath(callbackPath);

  bool matchesCallbackPath(String path) {
    return _normalizePath(path) == normalizedCallbackPath;
  }

  Uri resolve(String path) => Uri.parse(baseUrl).resolve(path);

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '/';
    }

    final normalized = path.startsWith('/') ? path : '/$path';
    if (normalized.length > 1 && normalized.endsWith('/')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
