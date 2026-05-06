// Basic smoke test for the Invisible AI Assistant app.
//
// Note: Full widget testing requires mocking window_manager and bitsdojo_window
// platform channels, which is beyond the scope of this initial setup.
// This test verifies the app widget can be instantiated.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invisible_ai_assistant/app.dart';

void main() {
  testWidgets('App widget builds without errors', (WidgetTester tester) async {
    // Build the app wrapped in ProviderScope (required for Riverpod).
    await tester.pumpWidget(
      const ProviderScope(
        child: InvisibleAIApp(),
      ),
    );

    // Verify the app title is rendered in the custom title bar.
    expect(find.text('Invisible AI'), findsOneWidget);
  });
}
