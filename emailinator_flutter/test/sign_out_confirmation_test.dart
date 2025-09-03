import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:emailinator_flutter/screens/home_screen.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'test_helpers.dart';

void main() {
  group('Sign Out Confirmation Dialog', () {
    setUp(() async {
      await ensureSupabaseInitialized();
    });

    testWidgets('shows confirmation dialog when logout button is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap the logout button
      final logoutButton = find.byIcon(Icons.logout);
      expect(logoutButton, findsOneWidget);
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // Assert - check that confirmation dialog appears
      expect(find.text('Sign Out'),
          findsNWidgets(2)); // One in dialog title, one in button
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('dismisses dialog when Cancel is tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - tap logout button and then cancel
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert - dialog should be dismissed
      expect(find.text('Sign Out'), findsNothing);
      expect(find.text('Are you sure you want to sign out?'), findsNothing);
    });
  });
}
