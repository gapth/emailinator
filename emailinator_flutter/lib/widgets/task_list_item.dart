import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emailinator_flutter/models/task.dart';
import 'package:emailinator_flutter/models/app_state.dart';

class TaskListItem extends StatelessWidget {
  final Task task;

  const TaskListItem({Key? key, required this.task}) : super(key: key);

  Future<void> _updateTaskStatus(BuildContext context, String status) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .update({'status': status})
          .eq('id', task.id);
      
      Provider.of<AppState>(context, listen: false).removeTask(task.id);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e')),
      );
    }
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
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
    return Slidable(
      key: ValueKey(task.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _updateTaskStatus(context, 'DISMISSED'),
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.do_not_disturb,
            label: 'Dismiss',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        dismissible: DismissiblePane(onDismissed: () {
          _updateTaskStatus(context, 'DONE');
        }),
        children: [
          SlidableAction(
            onPressed: (context) => _updateTaskStatus(context, 'DONE'),
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
    );
  }
}
