import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailinator_flutter/models/task.dart';

class AppState extends ChangeNotifier {
  List<Task> _overdueTasks = [];
  List<Task> _upcomingTasks = [];
  List<Task> _historyTasks = [];
  bool _isLoading = false;
  DateTimeRange? _dateRange;
  bool _showHistory = false;
  List<String> _parentRequirementLevels = [];
  int _dateStartOffsetDays = -7;
  int _dateEndOffsetDays = 30;
  int _overdueGraceDays = 14;

  // Computed property that combines overdue and upcoming tasks for backward compatibility
  List<Task> get tasks => [..._overdueTasks, ..._upcomingTasks];
  List<Task> get overdueTasks => _overdueTasks;
  List<Task> get upcomingTasks => _upcomingTasks;
  List<Task> get historyTasks => _historyTasks;
  bool get isLoading => _isLoading;
  bool get showHistory => _showHistory;
  DateTimeRange? get dateRange => _dateRange;
  List<String> getParentRequirementLevels() =>
      List<String>.from(_parentRequirementLevels);
  int get dateStartOffsetDays => _dateStartOffsetDays;
  int get dateEndOffsetDays => _dateEndOffsetDays;
  int get overdueGraceDays => _overdueGraceDays;

  void setDateRange(DateTimeRange? newDateRange) {
    _dateRange = newDateRange;

    // Calculate and save new offsets when user manually selects a date range
    if (newDateRange != null) {
      final now = DateTime.now();
      _dateStartOffsetDays = newDateRange.start.difference(now).inDays;
      _dateEndOffsetDays = newDateRange.end.difference(now).inDays;
      _saveDateOffsetPreferences();
    }

    notifyListeners();
  }

  /// Get the default date range based on current offset preferences
  DateTimeRange getDefaultDateRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.add(Duration(days: _dateStartOffsetDays)),
      end: now.add(Duration(days: _dateEndOffsetDays)),
    );
  }

  /// Set the date range to the default based on current offset preferences
  void setDateRangeToDefault() {
    _dateRange = getDefaultDateRange();
    notifyListeners();
  }

  void setShowHistory(bool showHistory) {
    _showHistory = showHistory;
    notifyListeners();
  }

  void setOverdueGraceDays(int days) {
    _overdueGraceDays = days;
    notifyListeners();
  }

  /// Get overdue tasks - now returns the fetched overdue tasks
  List<Task> getOverdueTasks() {
    return _overdueTasks;
  }

  /// Get upcoming tasks - now returns the fetched upcoming tasks
  List<Task> getUpcomingTasks() {
    return _upcomingTasks;
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
              'parent_requirement_levels, show_history, date_start_offset_days, date_end_offset_days, overdue_grace_days')
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        _parentRequirementLevels =
            List<String>.from(prefs['parent_requirement_levels'] ?? []);
        _showHistory = prefs['show_history'] ?? false;
        _dateStartOffsetDays = prefs['date_start_offset_days'] ?? -7;
        _dateEndOffsetDays = prefs['date_end_offset_days'] ?? 30;
        _overdueGraceDays = prefs['overdue_grace_days'] ?? 14;
      }

      // Fetch all sections in parallel
      await Future.wait([
        _fetchOverdueTasks(),
        _fetchUpcomingTasks(),
        if (_showHistory) _fetchHistoryTasks(),
      ]);

      if (!_showHistory) {
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

  Future<void> _fetchOverdueTasks() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final graceThreshold = today.subtract(Duration(days: _overdueGraceDays));

      var overdueQuery = Supabase.instance.client
          .from('user_tasks')
          .select()
          .or('state.eq.OPEN,and(state.eq.SNOOZED,snoozed_until.lte.${DateTime.now().toIso8601String()})')
          .or('due_date.is.null,due_date.lt.${today.toIso8601String()}'); // Past due or no due date

      if (_parentRequirementLevels.isNotEmpty) {
        overdueQuery = overdueQuery.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      final overdueResponse =
          await overdueQuery.order('due_date', ascending: true);
      final overdueCandidates =
          (overdueResponse as List).map((item) => Task.fromJson(item)).toList();

      // Filter in memory to apply grace period logic for tasks with no due date
      _overdueTasks = overdueCandidates.where((task) {
        final effectiveDueDate = task.dueDate ?? task.createdAt;
        final taskDay = DateTime(effectiveDueDate.year, effectiveDueDate.month,
            effectiveDueDate.day);

        // Task is overdue (due date in the past) AND within grace period
        return taskDay.isBefore(today) && !taskDay.isBefore(graceThreshold);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching overdue tasks: $e');
      _overdueTasks = [];
    }
  }

  Future<void> _fetchUpcomingTasks() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      var upcomingQuery = Supabase.instance.client.from('user_tasks').select().or(
          'state.eq.OPEN,and(state.eq.SNOOZED,snoozed_until.lte.${DateTime.now().toIso8601String()})');

      if (_parentRequirementLevels.isNotEmpty) {
        upcomingQuery = upcomingQuery.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
      }

      if (_dateRange != null) {
        // Date range controls upcoming section only
        upcomingQuery = upcomingQuery.or(
            'due_date.is.null,and(due_date.gte.${_dateRange!.start.toIso8601String()},due_date.lte.${_dateRange!.end.toIso8601String()})');
      }

      final upcomingResponse =
          await upcomingQuery.order('due_date', ascending: true);
      final upcomingCandidates = (upcomingResponse as List)
          .map((item) => Task.fromJson(item))
          .toList();

      // Filter to only include tasks due today or in the future
      _upcomingTasks = upcomingCandidates.where((task) {
        final effectiveDueDate = task.dueDate ?? task.createdAt;
        final taskDay = DateTime(effectiveDueDate.year, effectiveDueDate.month,
            effectiveDueDate.day);

        // Task is due today or in the future
        return !taskDay.isBefore(today);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching upcoming tasks: $e');
      _upcomingTasks = [];
    }
  }

  Future<void> _fetchHistoryTasks() async {
    try {
      final now = DateTime.now();
      final historyThreshold = now.subtract(const Duration(days: 60));

      var historyQuery = Supabase.instance.client
          .from('user_tasks')
          .select()
          .or(
              'state.eq.COMPLETED,state.eq.DISMISSED,and(state.eq.SNOOZED,snoozed_until.gt.${DateTime.now().toIso8601String()})')
          .gte('updated_at',
              historyThreshold.toIso8601String()); // Only last 60 days

      if (_parentRequirementLevels.isNotEmpty) {
        historyQuery = historyQuery.inFilter(
            'parent_requirement_level', _parentRequirementLevels);
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
    _overdueTasks.removeWhere((task) => task.id == taskId);
    _upcomingTasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  void addTask(Task task) {
    // Remove from all lists first to avoid duplicates
    removeTask(task.id);

    // Add to appropriate list based on task date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveDueDate = task.dueDate ?? task.createdAt;
    final taskDay = DateTime(
        effectiveDueDate.year, effectiveDueDate.month, effectiveDueDate.day);

    if (taskDay.isBefore(today)) {
      // Check if within grace period for overdue
      final graceThreshold = today.subtract(Duration(days: _overdueGraceDays));
      if (!taskDay.isBefore(graceThreshold)) {
        _overdueTasks.add(task);
      }
    } else {
      _upcomingTasks.add(task);
    }

    notifyListeners();
  }

  /// Insert a task back at a specific index (used for undo operations).
  /// This works with the combined tasks list for backward compatibility.
  void insertTaskAt(Task task, int index) {
    final combinedTasks = tasks; // Get current combined list
    if (combinedTasks.indexWhere((t) => t.id == task.id) != -1) {
      return; // already present
    }

    // Simply use addTask which will put it in the right section
    addTask(task);
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

  Future<void> _saveDateOffsetPreferences() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('preferences').upsert({
        'user_id': userId,
        'date_start_offset_days': _dateStartOffsetDays,
        'date_end_offset_days': _dateEndOffsetDays,
      });
    } catch (e) {
      debugPrint('Error saving date offset preferences: $e');
    }
  }

  Future<void> saveOverdueGraceDays() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('preferences').upsert({
        'user_id': userId,
        'overdue_grace_days': _overdueGraceDays,
      });
    } catch (e) {
      debugPrint('Error saving overdue grace days: $e');
    }
  }
}
