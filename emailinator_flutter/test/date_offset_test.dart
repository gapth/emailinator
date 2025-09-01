import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/models/app_state.dart';

void main() {
  group('Date Offset Functionality Tests', () {
    test('getDefaultDateRange uses offset preferences', () {
      final appState = AppState();

      // Test with default offsets (-7 and 30 days)
      final defaultRange = appState.getDefaultDateRange();
      final now = DateTime.now();

      // Check that the default range uses the correct offsets
      expect(defaultRange.start.day, equals(now.add(Duration(days: -7)).day));
      expect(defaultRange.end.day, equals(now.add(Duration(days: 30)).day));
    });

    test('setDateRange calculates and updates offsets approximately', () {
      final appState = AppState();
      final now = DateTime.now();

      // Set a custom date range
      final customRange = DateTimeRange(
        start: now.add(Duration(days: -14)), // 2 weeks ago
        end: now.add(Duration(days: 60)), // 2 months ahead
      );

      appState.setDateRange(customRange);

      // Check that offsets were calculated approximately correctly
      // Allow for ±1 day difference due to potential timing issues
      expect(appState.dateStartOffsetDays, inInclusiveRange(-15, -13));
      expect(appState.dateEndOffsetDays, inInclusiveRange(59, 61));
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
      expect(appState.dateRange!.start.day,
          equals(now.add(Duration(days: -7)).day));
      expect(
          appState.dateRange!.end.day, equals(now.add(Duration(days: 30)).day));
    });
  });
}
