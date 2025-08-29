import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:emailinator_flutter/models/app_state.dart';
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
        final week = today.add(const Duration(days: 7));
        appState.setDateRange(DateTimeRange(start: today, end: week));
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
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 7)),
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

                return RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    itemCount: appState.tasks.length,
                    itemBuilder: (context, index) {
                      final task = appState.tasks[index];
                      return TaskListItem(task: task);
                    },
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
