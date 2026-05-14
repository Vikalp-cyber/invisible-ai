import 'package:flutter_test/flutter_test.dart';
import 'package:invisible_ai_assistant/features/auth/data/models/desktop_oauth_config.dart';

void main() {
  group('DesktopOAuthConfig', () {
    test(
      'default authorize URL uses the API auth route without redirect_uri',
      () {
        final config = DesktopOAuthConfig.fromEnvironment();

        expect(
          config.callbackUri.toString(),
          'http://flowdesk-backend.luminoai.online:45872/callback',
        );
        expect(
          config.googleAuthUri.toString(),
          'https://flowdesk-backend.luminoai.online/api/auth/google',
        );
        expect(
          config.googleAuthUri.queryParameters.containsKey('redirect_uri'),
          isFalse,
        );
      },
    );

    test(
      'buildGoogleAuthUri appends state and preserves existing query params',
      () {
        final config = _buildConfig(
          googleAuthPath: '/api/auth/google?source=desktop',
        );

        final authorizeUri = config.buildGoogleAuthUri(state: 'deadbeef');

        expect(
          authorizeUri.toString(),
          'https://flowdesk-backend.luminoai.online/api/auth/google?source=desktop&state=deadbeef',
        );
      },
    );

    test('matchesCallbackPath normalizes trailing slashes', () {
      final config = _buildConfig(callbackPath: 'callback/');

      expect(config.matchesCallbackPath('/callback'), isTrue);
      expect(config.matchesCallbackPath('/callback/'), isTrue);
      expect(config.matchesCallbackPath('/oauth/callback'), isFalse);
    });
  });
}

DesktopOAuthConfig _buildConfig({
  String googleAuthPath = '/api/auth/google',
  String callbackPath = '/callback',
}) {
  return DesktopOAuthConfig(
    baseUrl: 'https://flowdesk-backend.luminoai.online',
    googleAuthPath: googleAuthPath,
    refreshPath: '/api/auth/refresh',
    mePath: '/api/auth/me',
    logoutPath: '',
    clientConfigPath: '/api/client-config',
    accessTokenParam: 'accessToken',
    refreshTokenParam: 'refreshToken',
    userParam: 'user',
    callbackHost: 'flowdesk-backend.luminoai.online',
    callbackPort: 45872,
    callbackPath: callbackPath,
    loginTimeout: const Duration(seconds: 180),
    tokenRefreshSkew: const Duration(seconds: 60),
  );
}
