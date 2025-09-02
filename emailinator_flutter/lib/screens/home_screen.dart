import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/widgets/task_list_item.dart';
import 'package:emailinator_flutter/widgets/resolved_task_list_item.dart';
import 'package:emailinator_flutter/widgets/filter_bar.dart';
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
      _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.fetchTasks();

    // Set default date range if none is set, using the loaded offset preferences
    if (appState.dateRange == null) {
      appState.setDateRangeToDefault();
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
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
          // Filter chips showing current state
          FilterBar(onFiltersChanged: _loadTasks),
          Expanded(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                if (appState.isLoading &&
                    appState.overdueTasks.isEmpty &&
                    appState.upcomingTasks.isEmpty &&
                    appState.completedTasks.isEmpty &&
                    appState.dismissedTasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (appState.overdueTasks.isEmpty &&
                    appState.upcomingTasks.isEmpty &&
                    appState.completedTasks.isEmpty &&
                    appState.dismissedTasks.isEmpty) {
                  return const Center(child: Text('No tasks found.'));
                }

                // Get overdue and upcoming tasks using AppState properties
                final overdueTasks = appState.overdueTasks;
                final upcomingTasks = appState.upcomingTasks;

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
                      // Overdue section - always shown at the top
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Overdue',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (overdueTasks.isNotEmpty)
                        ...overdueTasks.map((task) => TaskListItem(task: task))
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'No overdue tasks',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Upcoming section - always shown
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Upcoming',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      if (upcomingTasks.isNotEmpty)
                        ...upcomingTasks.map((task) => TaskListItem(task: task))
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'No upcoming tasks',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Resolved section (formerly History) - always shown if filters allow
                      if (appState.resolvedShowCompleted ||
                          appState.resolvedShowDismissed) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Resolved',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                          ),
                        ),

                        // Completed group - always shown if filter allows
                        if (appState.resolvedShowCompleted) ...[
                          ExpansionTile(
                            title: Text(
                                'Completed (${appState.completedTasks.length})'),
                            initiallyExpanded: true,
                            children: appState.completedTasks.isNotEmpty
                                ? appState.completedTasks
                                    .map((task) =>
                                        ResolvedTaskListItem(task: task))
                                    .toList()
                                : [
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No completed tasks',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                          ),
                        ],

                        // Dismissed group - always shown if filter allows
                        if (appState.resolvedShowDismissed) ...[
                          ExpansionTile(
                            title: Text(
                                'Dismissed (${appState.dismissedTasks.length})'),
                            initiallyExpanded: true,
                            children: appState.dismissedTasks.isNotEmpty
                                ? appState.dismissedTasks
                                    .map((task) =>
                                        ResolvedTaskListItem(task: task))
                                    .toList()
                                : [
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No dismissed tasks',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                          ),
                        ],
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
