import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/models/task.dart';

void main() {
  group('Task effective due date', () {
    test('uses dueDate when available', () {
      final dueDate = DateTime(2025, 9, 15);
      final sentAt = DateTime(2025, 9, 10);
      final createdAt = DateTime(2025, 9, 5);

      final task = Task(
        id: 'test-task',
        userId: 'test-user',
        title: 'Test Task',
        dueDate: dueDate,
        createdAt: createdAt,
        updatedAt: createdAt,
        sentAt: sentAt,
      );

      // When dueDate is available, it should be used as the effective due date
      expect(task.getEffectiveDueDate(), equals(dueDate));
    });

    test('uses sentAt when dueDate is null', () {
      final sentAt = DateTime(2025, 9, 10);
      final createdAt = DateTime(2025, 9, 5);

      final task = Task(
        id: 'test-task',
        userId: 'test-user',
        title: 'Test Task',
        dueDate: null,
        createdAt: createdAt,
        updatedAt: createdAt,
        sentAt: sentAt,
      );

      // When dueDate is null, sentAt should be used as the effective due date
      expect(task.getEffectiveDueDate(), equals(sentAt));
    });

    test('falls back to createdAt when both dueDate and sentAt are null', () {
      final createdAt = DateTime(2025, 9, 5);

      final task = Task(
        id: 'test-task',
        userId: 'test-user',
        title: 'Test Task',
        dueDate: null,
        createdAt: createdAt,
        updatedAt: createdAt,
        sentAt: null,
      );

      // When both dueDate and sentAt are null, createdAt should be used
      expect(task.getEffectiveDueDate(), equals(createdAt));
    });

    test('UI display logic uses sentAt when dueDate is null', () {
      final sentAt = DateTime(2025, 9, 10);
      final createdAt = DateTime(2025, 9, 5);

      final task = Task(
        id: 'test-task',
        userId: 'test-user',
        title: 'Test Task',
        dueDate: null,
        createdAt: createdAt,
        updatedAt: createdAt,
        sentAt: sentAt,
      );

      // Simulate the UI display logic from task_list_item.dart
      final displayDate = task.dueDate?.toIso8601String().substring(0, 10) ??
          (task.sentAt ?? task.createdAt).toIso8601String().substring(0, 10);

      expect(displayDate,
          equals('2025-09-10')); // Should use sentAt, not createdAt
    });

    test('UI display logic falls back to createdAt when sentAt is null', () {
      final createdAt = DateTime(2025, 9, 5);

      final task = Task(
        id: 'test-task',
        userId: 'test-user',
        title: 'Test Task',
        dueDate: null,
        createdAt: createdAt,
        updatedAt: createdAt,
        sentAt: null,
      );

      // Simulate the UI display logic from task_list_item.dart
      final displayDate = task.dueDate?.toIso8601String().substring(0, 10) ??
          (task.sentAt ?? task.createdAt).toIso8601String().substring(0, 10);

      expect(
          displayDate, equals('2025-09-05')); // Should fall back to createdAt
    });

    test('Task.fromJson correctly parses sentAt field', () {
      final json = {
        'id': 'test-task',
        'user_id': 'test-user',
        'title': 'Test Task',
        'created_at': '2025-09-05T10:00:00Z',
        'updated_at': '2025-09-05T10:00:00Z',
        'sent_at': '2025-09-10T12:00:00Z',
      };

      final task = Task.fromJson(json);

      expect(task.sentAt, isNotNull);
      expect(
          task.sentAt?.toIso8601String(), equals('2025-09-10T12:00:00.000Z'));
    });

    test('Task.fromJson handles null sentAt field', () {
      final json = {
        'id': 'test-task',
        'user_id': 'test-user',
        'title': 'Test Task',
        'created_at': '2025-09-05T10:00:00Z',
        'updated_at': '2025-09-05T10:00:00Z',
        'sent_at': null,
      };

      final task = Task.fromJson(json);

      expect(task.sentAt, isNull);
    });
  });
}
