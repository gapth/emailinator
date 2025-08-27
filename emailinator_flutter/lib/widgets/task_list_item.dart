import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emailinator_flutter/models/task.dart';
import 'package:emailinator_flutter/models/app_state.dart';

class TaskListItem extends StatefulWidget {
  final Task task;

  const TaskListItem({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskListItem> createState() => _TaskListItemState();
}

class _TaskListItemState extends State<TaskListItem> {
  bool _isProcessing = false;

  Future<void> _updateTaskStatus(String status) async {
    if (_isProcessing) return; // guard against double triggers
    setState(() => _isProcessing = true);

    final appState = Provider.of<AppState>(context, listen: false);
    final task = widget.task;
    final originalStatus = task.status;
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
          status == 'DONE'
              ? 'Marked task as done'
              : 'Dismissed task',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            undoRequested = true;
            // Restore at original index (fallback to end if somehow not found)
            appState.insertTaskAt(task, originalIndex == -1 ? appState.tasks.length : originalIndex);
            try {
              await Supabase.instance.client
                  .from('tasks')
                  .update({'status': originalStatus})
                  .eq('id', task.id);
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
    await Supabase.instance.client
      .from('tasks')
      .update({'status': status})
      .eq('id', task.id);
    } catch (e) {
      // Rollback on failure
      if (!undoRequested) {
  appState.insertTaskAt(task, originalIndex == -1 ? appState.tasks.length : originalIndex);
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

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final task = widget.task;
        final lines = <Widget>[];

        Widget addSection(String label, String? value) {
          if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichText(
              text: TextSpan(
                style: Theme.of(ctx).textTheme.bodyMedium,
                children: [
                  TextSpan(text: '$label', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          addSection('Consequence if ignored:', task.consequenceIfIgnore),
          addSection('Due:', task.dueDate != null ? task.dueDate!.toIso8601String().substring(0, 10) : null),
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
              dismissible: DismissiblePane(onDismissed: () => _updateTaskStatus('DISMISSED')),
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
              dismissible: DismissiblePane(onDismissed: () => _updateTaskStatus('DONE')),
              children: [
                SlidableAction(
                  onPressed: (context) => _updateTaskStatus('DONE'),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  icon: Icons.check_circle,
                  label: 'Done',
                ),
              ],
            ),
            child: ListTile(
              title: Text(task.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.dueDate != null)
                    Text('Due: ${task.dueDate.toString().substring(0, 10)}'),
                  if (task.parentRequirementLevel != null)
                    Text('Parent requirement: ${task.parentRequirementLevel}'),
                ],
              ),
              onTap: () => _showDetails(context),
            ),
          ),
      ),
    );
  }
}
