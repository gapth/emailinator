import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:emailinator_flutter/models/task.dart';

class HistoryTaskListItem extends StatelessWidget {
  final Task task;

  const HistoryTaskListItem({super.key, required this.task});

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final task = this.task;
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
          addSection('Consequence if ignored:', task.consequenceIfIgnore),
          addSection(
              task.dueDate != null ? 'Due:' : 'Due?:',
              task.dueDate?.toIso8601String().substring(0, 10) ??
                  task.createdAt.toIso8601String().substring(0, 10)),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, y').format(date);
  }

  Widget _buildStatusInfo() {
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
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        task.title,
        style: TextStyle(
          decoration:
              task.state == 'COMPLETED' ? TextDecoration.lineThrough : null,
          color: task.state == 'COMPLETED' ? Colors.grey[600] : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (task.dueDate != null)
            Text('Due: ${task.dueDate.toString().substring(0, 10)}')
          else
            Text('Due?: ${task.createdAt.toString().substring(0, 10)}'),
          if (task.parentRequirementLevel != null)
            Text('Parent requirement: ${task.parentRequirementLevel}'),
          const SizedBox(height: 4),
          _buildStatusInfo(),
        ],
      ),
      onTap: () => _showDetails(context),
    );
  }
}
