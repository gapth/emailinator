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

    testWidgets('FilterBar displays overdue chip', (WidgetTester tester) async {
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

      expect(find.text('Overdue: 14d'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
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

      // Should show overdue chip, requirement levels chip, and history chip
      expect(find.byType(ActionChip),
          findsNWidgets(2)); // Overdue + Requirements chips
      expect(find.byType(FilterChip), findsOneWidget); // History chip
      expect(find.text('All Requirements'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Overdue: 14d'), findsOneWidget); // New overdue chip
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

      // Find ActionChip widgets (date, overdue, and requirements)
      expect(find.byType(ActionChip), findsNWidgets(3));
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

    testWidgets(
        'FilterBar shows parent requirement bottom sheet when requirement chip is tapped',
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

      // Find and tap the requirements chip
      final requirementChip = find.ancestor(
        of: find.text('All Requirements'),
        matching: find.byType(ActionChip),
      );

      await tester.tap(requirementChip);
      await tester.pumpAndSettle();

      // Check that the bottom sheet appears with parent requirement levels
      expect(find.text('Parent Requirement Levels'), findsOneWidget);
      expect(find.text('NONE'), findsOneWidget);
      expect(find.text('OPTIONAL'), findsOneWidget);
      expect(find.text('VOLUNTEER'), findsOneWidget);
      expect(find.text('MANDATORY'), findsOneWidget);

      // Check that checkboxes are present
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
    });

    testWidgets(
        'FilterBar shows "All Requirements" when all levels are selected',
        (WidgetTester tester) async {
      final appState = AppState();
      // Set all requirement levels
      appState.setParentRequirementLevels(
          ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY']);

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

      // Should show "All Requirements" when all levels are selected
      expect(find.text('All Requirements'), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('FilterBar shows specific levels when partially selected',
        (WidgetTester tester) async {
      final appState = AppState();
      // Set only some requirement levels
      appState.setParentRequirementLevels(['MANDATORY', 'OPTIONAL']);

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

      // Should show the specific selected levels, not "All Requirements"
      expect(find.text('Mandatory, Optional'), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });
  });
}
