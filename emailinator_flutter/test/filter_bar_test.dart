import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/widgets/filter_bar.dart';

void main() {
  group('FilterBar Widget Tests', () {
    testWidgets('FilterBar displays date range chip when date range is set',
        (WidgetTester tester) async {
      final appState = AppState();
      final dateRange = DateTimeRange(
        start: DateTime(2025, 8, 22),
        end: DateTime(2025, 9, 30),
      );
      appState.setDateRange(dateRange);

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

      expect(find.text('Aug 22 – Sep 30'), findsOneWidget);
      expect(find.byIcon(Icons.date_range), findsOneWidget);
    });

    testWidgets('FilterBar displays requirement levels chip',
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

      expect(find.text('All Requirements'), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('FilterBar handles empty state correctly',
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

      // Should still show requirement levels chip even when empty (shows "All Requirements")
      // And should show History chip
      expect(find.byType(ActionChip), findsOneWidget); // Requirements chip
      expect(find.byType(FilterChip), findsOneWidget); // History chip
      expect(find.text('All Requirements'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('FilterBar chips are interactive', (WidgetTester tester) async {
      final appState = AppState();
      final dateRange = DateTimeRange(
        start: DateTime(2025, 8, 22),
        end: DateTime(2025, 9, 30),
      );
      appState.setDateRange(dateRange);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: Scaffold(
              body: FilterBar(onFiltersChanged: () {}),
            ),
          ),
        ),
      );

      // Find ActionChip widgets (date and requirements)
      expect(find.byType(ActionChip), findsNWidgets(2));
      // Find FilterChip widget (history)
      expect(find.byType(FilterChip), findsOneWidget);

      // Test that chips are tappable by finding them
      final dateChip = find.ancestor(
        of: find.text('Aug 22 – Sep 30'),
        matching: find.byType(ActionChip),
      );
      expect(dateChip, findsOneWidget);

      final requirementChip = find.ancestor(
        of: find.text('All Requirements'),
        matching: find.byType(ActionChip),
      );
      expect(requirementChip, findsOneWidget);
    });
  });
}
