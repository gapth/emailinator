import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:emailinator_flutter/models/task.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/utils/date_provider.dart';

class TaskListItem extends StatefulWidget {
  final Task task;

  const TaskListItem({super.key, required this.task});

  @override
  State<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends State<TaskListItem> {
  bool _isProcessing = false;

  Future<void> _updateTaskStatus(String newState,
      {DateTime? snoozedUntil}) async {
    if (_isProcessing) return; // guard against double triggers
    setState(() => _isProcessing = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final task = widget.task;
    final originalState = task.state;
    // Record original index so we can restore ordering on undo
    final originalIndex = appState.tasks.indexWhere((t) => t.id == task.id);

    // Optimistic remove
    appState.removeTask(task.id);

    bool undoRequested = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          newState == 'COMPLETED'
              ? 'Marked task as completed'
              : newState == 'DISMISSED'
                  ? 'Dismissed task'
                  : 'Snoozed task',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            undoRequested = true;
            // Restore at original index (fallback to end if somehow not found)
            appState.insertTaskAt(task,
                originalIndex == -1 ? appState.tasks.length : originalIndex);
            try {
              await Supabase.instance.client.from('user_task_states').upsert({
                'user_id': task.userId,
                'task_id': task.id,
                'state': originalState,
                'completed_at': null,
                'dismissed_at': null,
                'snoozed_until': null,
              }, onConflict: 'user_id, task_id');
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Failed to undo: $e')),
              );
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final updateData = <String, dynamic>{
        'user_id': task.userId,
        'task_id': task.id,
        'state': newState,
        'completed_at': newState == 'COMPLETED'
            ? DateProvider.now().toIso8601String()
            : null,
        'dismissed_at': newState == 'DISMISSED'
            ? DateProvider.now().toIso8601String()
            : null,
        'snoozed_until':
            newState == 'SNOOZED' ? snoozedUntil?.toIso8601String() : null,
      };

      await Supabase.instance.client
          .from('user_task_states')
          .upsert(updateData, onConflict: 'user_id, task_id');

      // Update the local task object and move it to the appropriate list
      if (newState == 'COMPLETED' ||
          newState == 'DISMISSED' ||
          newState == 'SNOOZED') {
        // Create an updated task object with the new state and timestamps
        final updatedTask = Task(
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
          updatedAt: DateProvider.now(),
          state: newState,
          completedAt:
              newState == 'COMPLETED' ? DateProvider.now() : task.completedAt,
          dismissedAt:
              newState == 'DISMISSED' ? DateProvider.now() : task.dismissedAt,
          snoozedUntil: newState == 'SNOOZED' ? snoozedUntil : null,
          sentAt: task.sentAt,
        );

        // Add the updated task to the appropriate list
        appState.addTask(updatedTask);
      }
    } catch (e) {
      // Rollback on failure
      if (!undoRequested) {
        appState.insertTaskAt(
            task, originalIndex == -1 ? appState.tasks.length : originalIndex);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _snoozeTask() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateProvider.now().add(const Duration(days: 1)),
      firstDate: DateProvider.now(),
      lastDate: DateProvider.now().add(const Duration(days: 365)),
      helpText: 'Snooze until',
    );

    if (selectedDate != null) {
      await _updateTaskStatus('SNOOZED', snoozedUntil: selectedDate);
    }
  }

  Future<void> _reopenTask() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final task = widget.task;

    try {
      await Supabase.instance.client.from('user_task_states').upsert({
        'user_id': task.userId,
        'task_id': task.id,
        'state': 'OPEN',
        'completed_at': null,
        'dismissed_at': null,
        'snoozed_until': null,
      }, onConflict: 'user_id, task_id');

      // Refresh tasks to show the reopened task
      await appState.fetchTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task reopened')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reopen task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, y').format(date);
  }

  Widget _buildStatusInfo() {
    final task = widget.task;
    if (task.state == 'COMPLETED' && task.completedAt != null) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            'Completed on ${_formatDate(task.completedAt)}',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (task.state == 'DISMISSED' && task.dismissedAt != null) {
      return Row(
        children: [
          const Icon(Icons.cancel, color: Colors.grey, size: 16),
          const SizedBox(width: 4),
          Text(
            'Dismissed on ${_formatDate(task.dismissedAt)}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (task.state == 'SNOOZED' && task.snoozedUntil != null) {
      return Row(
        children: [
          const Icon(Icons.snooze, color: Colors.orange, size: 16),
          const SizedBox(width: 4),
          Text(
            'Snoozed until ${_formatDate(task.snoozedUntil)}',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final task = widget.task;
        final lines = <Widget>[];

        Widget addSection(String label, String? value) {
          if (value == null || value.trim().isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichText(
              text: TextSpan(
                style: Theme.of(ctx).textTheme.bodyMedium,
                children: [
                  TextSpan(
                      text: label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' '),
                  TextSpan(text: value),
                ],
              ),
            ),
          );
        }

        lines.addAll([
          if (task.description != null && task.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(task.description!),
            ),
          addSection('Parent action:', task.parentAction),
          addSection('Parent requirement:', task.parentRequirementLevel),
          addSection('Student action:', task.studentAction),
          addSection('Student requirement:', task.studentRequirementLevel),
          addSection(
              task.dueDate != null ? 'Due:' : 'Due?:',
              task.dueDate?.toIso8601String().substring(0, 10) ??
                  task
                      .getEffectiveDueDate()
                      .toIso8601String()
                      .substring(0, 10)),
          // Add status info if task is completed/dismissed/snoozed
          if (task.state != null && task.state != 'OPEN') ...[
            const SizedBox(height: 8),
            _buildStatusInfo(),
          ],
        ]);

        // Remove empty sized boxes
        final content = lines.where((w) => w is! SizedBox).toList();

        return AlertDialog(
          title: Text(task.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: content.isEmpty
                  ? [const Text('No additional details.')]
                  : content,
            ),
          ),
          actions: [
            // Show different actions based on task state
            if (task.state == null || task.state == 'OPEN') ...[
              // Primary action buttons for open tasks
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _updateTaskStatus('DISMISSED');
                },
                icon: const Icon(Icons.do_not_disturb),
                label: const Text('Dismiss'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _snoozeTask();
                },
                icon: const Icon(Icons.snooze),
                label: const Text('Snooze'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _updateTaskStatus('COMPLETED');
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
              ),
            ] else if (task.state == 'SNOOZED') ...[
              // Actions for snoozed tasks
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _updateTaskStatus('DISMISSED');
                },
                icon: const Icon(Icons.do_not_disturb),
                label: const Text('Dismiss'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _reopenTask();
                },
                icon: const Icon(Icons.undo),
                label: const Text('Unsnooze'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _updateTaskStatus('COMPLETED');
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Complete'),
              ),
            ] else ...[
              // Reopen action for completed/dismissed tasks
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _reopenTask();
                },
                icon: const Icon(Icons.undo),
                label: const Text('Reopen'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Opacity(
      opacity: _isProcessing ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: _isProcessing,
        child: Slidable(
          key: ValueKey(task.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            dismissible: DismissiblePane(
                onDismissed: () => _updateTaskStatus('DISMISSED')),
            children: [
              SlidableAction(
                onPressed: (context) => _updateTaskStatus('DISMISSED'),
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                icon: Icons.do_not_disturb,
                label: 'Dismiss',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            dismissible: DismissiblePane(
                onDismissed: () => _updateTaskStatus('COMPLETED')),
            children: [
              SlidableAction(
                onPressed: (context) => _updateTaskStatus('COMPLETED'),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: Icons.check_circle,
                label: 'Complete',
              ),
            ],
          ),
          child: ListTile(
            title: Text(task.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.dueDate != null)
                  Text('Due: ${task.dueDate.toString().substring(0, 10)}')
                else
                  Text(
                      'Due?: ${task.getEffectiveDueDate().toString().substring(0, 10)}'),
                if (task.parentRequirementLevel != null)
                  Text('Parent requirement: ${task.parentRequirementLevel}'),
                if (task.state == 'SNOOZED' && task.snoozedUntil != null)
                  Row(
                    children: [
                      const Icon(Icons.snooze, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Snoozed until ${_formatDate(task.snoozedUntil)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            onTap: () => _showDetails(context),
          ),
        ),
      ),
    );
  }
}
