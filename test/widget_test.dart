// Basic smoke test for the Flowdesk app.
//
// Note: Full widget testing requires mocking window_manager and bitsdojo_window
// platform channels, which is beyond the scope of this initial setup.
// This test verifies the app widget can be instantiated.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invisible_ai_assistant/app.dart';
import 'package:invisible_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoading: false);
}

void main() {
  testWidgets('App widget builds the sign-in shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_TestAuthNotifier.new)],
        child: FlowdeskApp(),
      ),
    );

    expect(find.text('Flowdesk'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
