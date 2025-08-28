// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emailinator_flutter/main.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async { await ensureSupabaseInitialized(); });

  testWidgets('Shows login screen when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
