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
        onTap: () {
          // TODO: Show task details dialog
        },
      ),
    );
  }
}
