import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/models/task.dart';

void main() {
  group('Snoozed Tasks', () {
    test('Task with future snoozed_until is added to snoozed list', () {
      final appState = AppState();

      // Create a task snoozed until tomorrow
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final snoozedTask = Task(
        id: 'snoozed-task-1',
        userId: 'test-user',
        title: 'Snoozed Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: tomorrow,
      );

      // Add the task to the app state
      appState.addTask(snoozedTask);

      // Verify it's in the snoozed tasks list
      expect(appState.snoozedTasks.length, 1);
      expect(appState.snoozedTasks.first.id, 'snoozed-task-1');
      expect(appState.snoozedTasks.first.state, 'SNOOZED');

      // Verify it's not in other lists
      expect(appState.overdueTasks.length, 0);
      expect(appState.upcomingTasks.length, 0);
      expect(appState.completedTasks.length, 0);
      expect(appState.dismissedTasks.length, 0);
    });

    test('Task with past snoozed_until is treated as OPEN task', () {
      final appState = AppState();

      // Create a task snoozed until yesterday
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final expiredSnoozedTask = Task(
        id: 'expired-snoozed-task-1',
        userId: 'test-user',
        title: 'Expired Snoozed Task',
        dueDate: DateTime.now().add(const Duration(days: 1)), // Due tomorrow
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: yesterday,
      );

      // Add the task to the app state
      appState.addTask(expiredSnoozedTask);

      // Verify it's in the upcoming tasks list (not snoozed)
      expect(appState.upcomingTasks.length, 1);
      expect(appState.upcomingTasks.first.id, 'expired-snoozed-task-1');

      // Verify it's not in the snoozed tasks list
      expect(appState.snoozedTasks.length, 0);
    });

    test(
        'Task snoozed until today is NOT in snoozed tasks but in upcoming tasks',
        () {
      final appState = AppState();

      // Create a task snoozed until today (start of day) with a future due date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final snoozedUntilTodayTask = Task(
        id: 'snoozed-until-today-task',
        userId: 'test-user',
        title: 'Snoozed Until Today Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: today,
        dueDate: tomorrow, // Due tomorrow so it goes to upcoming
      );

      // Add the task to the app state
      appState.addTask(snoozedUntilTodayTask);

      // Verify it's NOT in the snoozed tasks list
      expect(appState.snoozedTasks.length, 0);

      // Verify it's in the upcoming tasks list instead
      expect(appState.upcomingTasks.length, 1);
      expect(appState.upcomingTasks.first.id, 'snoozed-until-today-task');
      expect(appState.upcomingTasks.first.state, 'SNOOZED');

      // Verify it's not in other lists
      expect(appState.overdueTasks.length, 0);
      expect(appState.completedTasks.length, 0);
      expect(appState.dismissedTasks.length, 0);
    });

    test('Task snoozed until today with past due date appears in overdue tasks',
        () {
      final appState = AppState();

      // Create a task snoozed until today with a past due date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final snoozedUntilTodayOverdueTask = Task(
        id: 'snoozed-until-today-overdue-task',
        userId: 'test-user',
        title: 'Snoozed Until Today Overdue Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: today,
        dueDate: yesterday, // Due yesterday so it goes to overdue
      );

      // Add the task to the app state
      appState.addTask(snoozedUntilTodayOverdueTask);

      // Verify it's NOT in the snoozed tasks list
      expect(appState.snoozedTasks.length, 0);

      // Verify it's in the overdue tasks list instead
      expect(appState.overdueTasks.length, 1);
      expect(
          appState.overdueTasks.first.id, 'snoozed-until-today-overdue-task');
      expect(appState.overdueTasks.first.state, 'SNOOZED');

      // Verify it's not in other lists
      expect(appState.upcomingTasks.length, 0);
      expect(appState.completedTasks.length, 0);
      expect(appState.dismissedTasks.length, 0);
    });

    test('Task is removed from all lists including snoozed', () {
      final appState = AppState();

      // Add a snoozed task
      final snoozedTask = Task(
        id: 'test-snoozed-task',
        userId: 'test-user',
        title: 'Test Snoozed Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: DateTime.now().add(const Duration(days: 1)),
      );
      appState.addTask(snoozedTask);

      // Verify it's in snoozed tasks
      expect(appState.snoozedTasks.length, 1);

      // Remove the task
      appState.removeTask('test-snoozed-task');

      // Verify it's removed from all lists
      expect(appState.snoozedTasks.length, 0);
      expect(appState.overdueTasks.length, 0);
      expect(appState.upcomingTasks.length, 0);
      expect(appState.completedTasks.length, 0);
      expect(appState.dismissedTasks.length, 0);
    });

    test('Task reopened from snoozed state has correct properties', () {
      final appState = AppState();

      // Create a task that was previously snoozed but is now reopened
      // This simulates what happens when the automatic reopening logic runs
      final reopenedTask = Task(
        id: 'reopened-task-1',
        userId: 'test-user',
        title: 'Reopened Task',
        dueDate: DateTime.now().add(const Duration(days: 1)), // Due tomorrow
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'OPEN', // State is now OPEN (reopened)
        snoozedUntil: null, // snoozedUntil should be null when reopened
      );

      // Add the task to the app state
      appState.addTask(reopenedTask);

      // Verify it's in the upcoming tasks list (not snoozed)
      expect(appState.upcomingTasks.length, 1);
      expect(appState.upcomingTasks.first.id, 'reopened-task-1');
      expect(appState.upcomingTasks.first.state, 'OPEN');
      expect(appState.upcomingTasks.first.snoozedUntil, null);

      // Verify it's not in the snoozed tasks list
      expect(appState.snoozedTasks.length, 0);

      // Verify it's not in other lists
      expect(appState.overdueTasks.length, 0);
      expect(appState.completedTasks.length, 0);
      expect(appState.dismissedTasks.length, 0);
    });
  });
}
