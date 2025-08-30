import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/models/task.dart';
import 'package:emailinator_flutter/widgets/task_list_item.dart';
import 'package:emailinator_flutter/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.dateRange == null) {
        final today = DateTime.now();
        final pastWeek = today.subtract(const Duration(days: 7));
        final futureMonth = today.add(const Duration(days: 30));
        appState.setDateRange(DateTimeRange(start: pastWeek, end: futureMonth));
      }
      _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.fetchTasks();
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final initialDateRange = appState.dateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now().add(const Duration(days: 30)),
        );
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 5),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null) {
      appState.setDateRange(newDateRange);
      _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadTasks();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Due:'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _selectDateRange(context),
                  child: Consumer<AppState>(
                    builder: (context, appState, child) {
                      if (appState.dateRange == null) {
                        return const Text('Select date range');
                      }
                      final start = appState.dateRange!.start;
                      final end = appState.dateRange!.end;
                      return Text(
                          '${start.toLocal().toString().split(' ')[0]} - ${end.toLocal().toString().split(' ')[0]}');
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                if (appState.isLoading && appState.tasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (appState.tasks.isEmpty) {
                  return const Center(child: Text('No tasks found.'));
                }

                // Separate tasks into overdue and upcoming
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final overdueTasks = <Task>[];
                final upcomingTasks = <Task>[];

                for (final task in appState.tasks) {
                  final taskDate = task.dueDate ?? task.createdAt;
                  final taskDay =
                      DateTime(taskDate.year, taskDate.month, taskDate.day);

                  if (taskDay.isBefore(today)) {
                    overdueTasks.add(task);
                  } else {
                    upcomingTasks.add(task);
                  }
                }

                // Sort each section by effective date (due date or created date)
                overdueTasks.sort((a, b) {
                  final aDate = a.dueDate ?? a.createdAt;
                  final bDate = b.dueDate ?? b.createdAt;
                  return aDate.compareTo(bDate);
                });

                upcomingTasks.sort((a, b) {
                  final aDate = a.dueDate ?? a.createdAt;
                  final bDate = b.dueDate ?? b.createdAt;
                  return aDate.compareTo(bDate);
                });

                return RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView(
                    children: [
                      // Overdue section
                      if (overdueTasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Overdue',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ...overdueTasks.map((task) => TaskListItem(task: task)),
                      ],

                      // Upcoming section
                      if (upcomingTasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Upcoming',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ...upcomingTasks
                            .map((task) => TaskListItem(task: task)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
