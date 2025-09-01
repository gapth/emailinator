import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailinator_flutter/models/task.dart';

class AppState extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> _historyTasks = [];
  bool _isLoading = false;
  DateTimeRange? _dateRange;
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
          .select('parent_requirement_levels, show_history')
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        _parentRequirementLevels =
            List<String>.from(prefs['parent_requirement_levels'] ?? []);
        _showHistory = prefs['show_history'] ?? false;
      }

      var query = Supabase.instance.client.from('user_tasks').select().or(
          'state.eq.OPEN,and(state.eq.SNOOZED,snoozed_until.lte.${DateTime.now().toIso8601String()})');

      if (_parentRequirementLevels.isNotEmpty) {
        query = query.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      if (_dateRange != null) {
        // Always include tasks with no due date and tasks within the date range
        query = query.or(
            'due_date.is.null,and(due_date.gte.${_dateRange!.start.toIso8601String()},due_date.lte.${_dateRange!.end.toIso8601String()})');
      }
      // Note: We always include tasks with no due date since creation date is used as effective due date

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
      var historyQuery = Supabase.instance.client.from('user_tasks').select().or(
          'state.eq.COMPLETED,state.eq.DISMISSED,and(state.eq.SNOOZED,snoozed_until.gt.${DateTime.now().toIso8601String()})');

      if (_parentRequirementLevels.isNotEmpty) {
        historyQuery = historyQuery.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      if (_dateRange != null) {
        // Always include tasks with no due date and tasks within the date range
        historyQuery = historyQuery.or(
            'due_date.is.null,and(due_date.gte.${_dateRange!.start.toIso8601String()},due_date.lte.${_dateRange!.end.toIso8601String()})');
      }
      // Note: We always include tasks with no due date since creation date is used as effective due date

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

  void setParentRequirementLevels(List<String> levels) {
    _parentRequirementLevels = List<String>.from(levels);
    notifyListeners();
  }

  Future<void> saveParentRequirementLevels() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('preferences').upsert({
        'user_id': userId,
        'parent_requirement_levels': _parentRequirementLevels,
      });
    } catch (e) {
      debugPrint('Error saving parent requirement levels: $e');
    }
  }
}
