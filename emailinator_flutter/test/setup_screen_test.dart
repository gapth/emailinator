import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/screens/setup_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureSupabaseInitialized();
  });

  testWidgets('Initial route /setup loads SetupScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/setup',
      routes: {
        '/setup': (c) => const SetupScreen(),
      },
    ));

    await tester.pump();
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Forward school emails to Emailinator'), findsOneWidget);
  });

  testWidgets('SetupScreen shows provider buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/setup',
      routes: {
        '/setup': (c) => const SetupScreen(),
      },
    ));

    await tester.pumpAndSettle();

    // Check that provider buttons are present
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.text('Outlook / Microsoft 365'), findsOneWidget);
    expect(find.text('iCloud'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });
}
