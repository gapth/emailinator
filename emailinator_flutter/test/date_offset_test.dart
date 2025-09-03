import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/models/app_state.dart';

void main() {
  group('Upcoming Days Functionality Tests', () {
    test('getDefaultDateRange uses upcoming_days preference', () {
      final appState = AppState();

      // Test with default upcoming_days (30 days)
      final defaultRange = appState.getDefaultDateRange();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check that the default range starts today and ends in 29 days (30 days total including today)
      expect(defaultRange.start, equals(today));
      expect(defaultRange.end, equals(today.add(const Duration(days: 29))));
    });

    test('setUpcomingDays updates the preference', () {
      final appState = AppState();

      // Initially 30 days
      expect(appState.upcomingDays, equals(30));

      // Change to 14 days
      appState.setUpcomingDays(14);
      expect(appState.upcomingDays, equals(14));

      // Test that getDefaultDateRange reflects the new preference
      final defaultRange = appState.getDefaultDateRange();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(defaultRange.start, equals(today));
      expect(defaultRange.end, equals(today.add(const Duration(days: 13))));
    });

    test('setDateRangeToDefault applies calculated default range', () {
      final appState = AppState();

      // Initially no date range is set
      expect(appState.dateRange, isNull);

      // Set to default
      appState.setDateRangeToDefault();

      // Should now have a date range
      expect(appState.dateRange, isNotNull);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(appState.dateRange!.start, equals(today));
      expect(
          appState.dateRange!.end, equals(today.add(const Duration(days: 29))));
    });

    test('upcoming_days=1 means today only', () {
      final appState = AppState();
      appState.setUpcomingDays(1);

      final defaultRange = appState.getDefaultDateRange();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(defaultRange.start, equals(today));
      expect(defaultRange.end, equals(today)); // Same day for 1 day
    });
  });
}
