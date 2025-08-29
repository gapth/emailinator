import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/screens/change_password_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureSupabaseInitialized();
  });
  testWidgets('Initial route /change-password loads ChangePasswordScreen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/change-password',
      routes: {
        '/change-password': (c) => const ChangePasswordScreen(),
      },
    ));

    await tester.pump();
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });
}
