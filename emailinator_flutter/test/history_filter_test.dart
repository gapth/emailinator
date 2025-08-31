import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/widgets/filter_bar.dart';

void main() {
  group('History Filter Toggle Tests', () {
    testWidgets('FilterBar displays History toggle chip',
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

      // Should show History chip
      expect(find.text('History'), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('History toggle changes state when tapped',
        (WidgetTester tester) async {
      final appState = AppState();

      // Initially should be false
      expect(appState.showHistory, false);

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

      // Find the History chip
      final historyChip = find.ancestor(
        of: find.text('History'),
        matching: find.byType(FilterChip),
      );
      expect(historyChip, findsOneWidget);

      // Tap the History chip
      await tester.tap(historyChip);
      await tester.pump();

      // State should now be true
      expect(appState.showHistory, true);
    });

    testWidgets('FilterBar shows correct number of chips including History',
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

      // Should have at least 2 chips: Requirements and History
      expect(find.byType(ActionChip),
          findsAtLeastNWidgets(1)); // Requirements chip
      expect(find.byType(FilterChip), findsOneWidget); // History chip
    });
  });
}
