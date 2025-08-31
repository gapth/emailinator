import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailinator_flutter/models/task.dart';

class AppState extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> _historyTasks = [];
  bool _isLoading = false;
  DateTimeRange? _dateRange;
  bool _includeNoDueDate = true;
  bool _showHistory = false;
  List<String> _parentRequirementLevels = [];

  List<Task> get tasks => _tasks;
  List<Task> get historyTasks => _historyTasks;
  bool get isLoading => _isLoading;
  bool get showHistory => _showHistory;
  DateTimeRange? get dateRange => _dateRange;
  List<String> getParentRequirementLevels() =>
      List<String>.from(_parentRequirementLevels);

  void setDateRange(DateTimeRange? newDateRange) {
    _dateRange = newDateRange;
    notifyListeners();
  }

  void setShowHistory(bool showHistory) {
    _showHistory = showHistory;
    notifyListeners();
  }

  Future<void> fetchTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // First, get user preferences
      final prefs = await Supabase.instance.client
          .from('preferences')
          .select(
              'parent_requirement_levels, include_no_due_date, show_history')
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        _parentRequirementLevels =
            List<String>.from(prefs['parent_requirement_levels'] ?? []);
        _includeNoDueDate = prefs['include_no_due_date'] ?? true;
        _showHistory = prefs['show_history'] ?? false;
      }

      var query = Supabase.instance.client
          .from('user_tasks')
          .select()
          .eq('state', 'OPEN');

      if (_parentRequirementLevels.isNotEmpty) {
        query = query.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      if (_dateRange != null) {
        if (_includeNoDueDate) {
          query = query.or(
              'due_date.is.null,and(due_date.gte.${_dateRange!.start.toIso8601String()},due_date.lte.${_dateRange!.end.toIso8601String()})');
        } else {
          query = query
              .gte('due_date', _dateRange!.start.toIso8601String())
              .lte('due_date', _dateRange!.end.toIso8601String());
        }
      } else if (!_includeNoDueDate) {
        query = query.not('due_date', 'is', null);
      }

      final response = await query.order('due_date', ascending: true);

      _tasks = (response as List).map((item) => Task.fromJson(item)).toList();

      // Fetch history tasks if enabled
      if (_showHistory) {
        await _fetchHistoryTasks();
      } else {
        _historyTasks = [];
      }
    } catch (e) {
      // Handle error - could use logging package or debugPrint in development
      debugPrint('Error fetching tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchHistoryTasks() async {
    try {
      var historyQuery = Supabase.instance.client
          .from('user_tasks')
          .select()
          .inFilter('state', ['COMPLETED', 'DISMISSED']);

      if (_parentRequirementLevels.isNotEmpty) {
        historyQuery = historyQuery.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      if (_dateRange != null) {
        if (_includeNoDueDate) {
          historyQuery = historyQuery.or(
              'due_date.is.null,and(due_date.gte.${_dateRange!.start.toIso8601String()},due_date.lte.${_dateRange!.end.toIso8601String()})');
        } else {
          historyQuery = historyQuery
              .gte('due_date', _dateRange!.start.toIso8601String())
              .lte('due_date', _dateRange!.end.toIso8601String());
        }
      } else if (!_includeNoDueDate) {
        historyQuery = historyQuery.not('due_date', 'is', null);
      }

      final historyResponse = await historyQuery
          .order('completed_at', ascending: false)
          .order('dismissed_at', ascending: false);

      _historyTasks =
          (historyResponse as List).map((item) => Task.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error fetching history tasks: $e');
      _historyTasks = [];
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  void addTask(Task task) {
    // Avoid duplicates if already present
    if (_tasks.indexWhere((t) => t.id == task.id) == -1) {
      _tasks.add(task);
      notifyListeners();
    }
  }

  /// Insert a task back at a specific index (used for undo operations).
  /// If the index is out of range it will be clamped to the valid bounds.
  /// Will not insert if a task with the same id already exists.
  void insertTaskAt(Task task, int index) {
    if (_tasks.indexWhere((t) => t.id == task.id) != -1) {
      return; // already present
    }
    if (index < 0) index = 0;
    if (index > _tasks.length) index = _tasks.length;
    _tasks.insert(index, task);
    notifyListeners();
  }

  Future<void> saveHistoryPreference() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('preferences').upsert({
        'user_id': userId,
        'show_history': _showHistory,
      });
    } catch (e) {
      debugPrint('Error saving history preference: $e');
    }
  }
}
