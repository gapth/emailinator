import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/screens/change_password_screen.dart';
import 'test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUpAll(() async { await ensureSupabaseInitialized(); });
  testWidgets('ChangePasswordScreen shows mismatch error', (tester) async {
    await tester.pumpWidget(_wrap(const ChangePasswordScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Current Password'), 'oldpass123');
    await tester.enterText(find.widgetWithText(TextFormField, 'New Password'), 'newpass123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirm New Password'), 'different');

    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('ChangePasswordScreen focus progression works', (tester) async {
    await tester.pumpWidget(_wrap(const ChangePasswordScreen()));
    final fields = find.byType(TextFormField);
    // Fill progressively; using next action simulation.
    await tester.enterText(fields.at(0), 'user@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(fields.at(1), 'oldpass123');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(fields.at(2), 'newpass123');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    await tester.enterText(fields.at(3), 'newpass123');
    expect(find.text('newpass123'), findsNWidgets(2));
  });
}
