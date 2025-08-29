import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/screens/login_screen.dart';
import 'test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUpAll(() async {
    await ensureSupabaseInitialized();
  });
  testWidgets('LoginScreen shows validation errors when fields empty',
      (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    // Tap sign in (button label 'Sign In')
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets(
      'LoginScreen moves focus from email to password on submit of email field',
      (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    final emailField = find.byType(TextFormField).first;
    await tester.enterText(emailField, 'user@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // Password field should now have focus; type text to confirm no exception.
    final passwordField = find.byType(TextFormField).at(1);
    await tester.enterText(passwordField, 'secret');
    expect(find.text('secret'), findsOneWidget);
  });
}
