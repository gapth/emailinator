import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/models/task.dart';
import 'package:emailinator_flutter/widgets/task_list_item.dart';

void main() {
  group('TaskListItem Display', () {
    testWidgets('Snoozed task displays snoozed until date with icon',
        (WidgetTester tester) async {
      // Create a snoozed task
      final snoozedDate = DateTime(2025, 9, 10);
      final snoozedTask = Task(
        id: 'snoozed-task-1',
        userId: 'test-user',
        title: 'Snoozed Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: snoozedDate,
        dueDate: DateTime(2025, 9, 7),
      );

      // Build the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AppState(),
              child: TaskListItem(task: snoozedTask),
            ),
          ),
        ),
      );

      // Verify the task title is displayed
      expect(find.text('Snoozed Task'), findsOneWidget);

      // Verify the due date is displayed
      expect(find.text('Due: 2025-09-07'), findsOneWidget);

      // Verify the snoozed until text is displayed
      expect(find.text('Snoozed until Sep 10, 2025'), findsOneWidget);

      // Verify the snooze icon is displayed
      expect(find.byIcon(Icons.snooze), findsOneWidget);

      // Verify the snooze icon has the correct color
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.snooze));
      expect(iconWidget.color, Colors.orange);
    });

    testWidgets('Non-snoozed task does not display snoozed information',
        (WidgetTester tester) async {
      // Create an open task
      final openTask = Task(
        id: 'open-task-1',
        userId: 'test-user',
        title: 'Open Task',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'OPEN',
        dueDate: DateTime(2025, 9, 7),
      );

      // Build the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AppState(),
              child: TaskListItem(task: openTask),
            ),
          ),
        ),
      );

      // Verify the task title is displayed
      expect(find.text('Open Task'), findsOneWidget);

      // Verify the due date is displayed
      expect(find.text('Due: 2025-09-07'), findsOneWidget);

      // Verify no snoozed information is displayed
      expect(find.textContaining('Snoozed until'), findsNothing);
      expect(find.byIcon(Icons.snooze), findsNothing);
    });

    testWidgets(
        'Task with parent requirement shows all information in correct order',
        (WidgetTester tester) async {
      // Create a snoozed task with parent requirement
      final snoozedDate = DateTime(2025, 9, 15);
      final taskWithParent = Task(
        id: 'task-with-parent',
        userId: 'test-user',
        title: 'Task with Parent Requirement',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        state: 'SNOOZED',
        snoozedUntil: snoozedDate,
        dueDate: DateTime(2025, 9, 7),
        parentRequirementLevel: 'OPTIONAL',
      );

      // Build the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider(
              create: (_) => AppState(),
              child: TaskListItem(task: taskWithParent),
            ),
          ),
        ),
      );

      // Verify all information is displayed
      expect(find.text('Task with Parent Requirement'), findsOneWidget);
      expect(find.text('Due: 2025-09-07'), findsOneWidget);
      expect(find.text('Snoozed until Sep 15, 2025'), findsOneWidget);
      expect(find.text('Parent requirement: OPTIONAL'), findsOneWidget);
      expect(find.byIcon(Icons.snooze), findsOneWidget);
    });
  });
}
