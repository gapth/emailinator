import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/widgets/filter_bar.dart';

void main() {
  group('Resolved Filter Toggle Tests', () {
    testWidgets('FilterBar displays Resolved toggle chip',
        (WidgetTester tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const Scaffold(
              body: FilterBar(),
            ),
          ),
        ),
      );

      // Should show Resolved chip
      expect(find.textContaining('Resolved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('Resolved toggle changes state when tapped',
        (WidgetTester tester) async {
      final appState = AppState();

      // Initially resolved settings should match defaults
      expect(appState.resolvedShowCompleted, true);
      expect(appState.resolvedShowDismissed, false);
      expect(appState.resolvedDays, 60);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const Scaffold(
              body: FilterBar(),
            ),
          ),
        ),
      );

      // Find the Resolved chip
      final resolvedChip = find.ancestor(
        of: find.textContaining('Resolved'),
        matching: find.byType(ActionChip),
      );
      expect(resolvedChip, findsOneWidget);

      // Tap the Resolved chip to open bottom sheet
      await tester.tap(resolvedChip);
      await tester.pumpAndSettle();

      // Check that the bottom sheet appears
      expect(find.text('Resolved Settings'), findsOneWidget);
    });

    testWidgets('FilterBar shows correct number of chips including Resolved',
        (WidgetTester tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: const Scaffold(
              body: FilterBar(),
            ),
          ),
        ),
      );

      // Should have at least 3 chips: Overdue, Requirements, and Resolved
      expect(find.byType(ActionChip),
          findsAtLeastNWidgets(3)); // Overdue, Requirements, Resolved chips
    });
  });
}
