import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/models/task.dart';

void main() {
  group('Task State Management Tests', () {
    test('Task moved to completed list when marked as COMPLETED', () {
      final appState = AppState();

      // Create a test task
      final task = Task(
        id: 'test-task-1',
        userId: 'test-user',
        title: 'Test Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'OPEN',
      );

      // Add it to upcoming tasks
      appState.addTask(task);

      // Verify it's in upcoming tasks
      expect(appState.upcomingTasks.length, 1);
      expect(appState.completedTasks.length, 0);
      expect(appState.upcomingTasks.first.id, 'test-task-1');

      // Create a completed version of the task
      final completedTask = Task(
        id: task.id,
        userId: task.userId,
        emailId: task.emailId,
        title: task.title,
        description: task.description,
        dueDate: task.dueDate,
        parentAction: task.parentAction,
        parentRequirementLevel: task.parentRequirementLevel,
        studentAction: task.studentAction,
        studentRequirementLevel: task.studentRequirementLevel,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
        state: 'COMPLETED',
        completedAt: DateTime.now(),
        dismissedAt: task.dismissedAt,
        snoozedUntil: task.snoozedUntil,
      );

      // Add the completed task (this should move it to completed list)
      appState.addTask(completedTask);

      // Verify it's now in completed tasks and not in upcoming
      expect(appState.upcomingTasks.length, 0);
      expect(appState.completedTasks.length, 1);
      expect(appState.completedTasks.first.id, 'test-task-1');
      expect(appState.completedTasks.first.state, 'COMPLETED');
    });

    test('Task moved to dismissed list when marked as DISMISSED', () {
      final appState = AppState();

      // Create a test task
      final task = Task(
        id: 'test-task-2',
        userId: 'test-user',
        title: 'Test Task 2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'OPEN',
      );

      // Add it to upcoming tasks
      appState.addTask(task);

      // Verify it's in upcoming tasks
      expect(appState.upcomingTasks.length, 1);
      expect(appState.dismissedTasks.length, 0);

      // Create a dismissed version of the task
      final dismissedTask = Task(
        id: task.id,
        userId: task.userId,
        emailId: task.emailId,
        title: task.title,
        description: task.description,
        dueDate: task.dueDate,
        parentAction: task.parentAction,
        parentRequirementLevel: task.parentRequirementLevel,
        studentAction: task.studentAction,
        studentRequirementLevel: task.studentRequirementLevel,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
        state: 'DISMISSED',
        completedAt: task.completedAt,
        dismissedAt: DateTime.now(),
        snoozedUntil: task.snoozedUntil,
      );

      // Add the dismissed task (this should move it to dismissed list)
      appState.addTask(dismissedTask);

      // Verify it's now in dismissed tasks and not in upcoming
      expect(appState.upcomingTasks.length, 0);
      expect(appState.dismissedTasks.length, 1);
      expect(appState.dismissedTasks.first.id, 'test-task-2');
      expect(appState.dismissedTasks.first.state, 'DISMISSED');
    });
  });
}
