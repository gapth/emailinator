import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailinator_flutter/models/task.dart';

class AppState extends ChangeNotifier {
  /// Helper method to check if database operations should be performed
  bool get _shouldPerformDatabaseOperations {
    try {
      // Try to access Supabase instance and check if user is authenticated
      final client = Supabase.instance.client;
      return client.auth.currentUser != null;
    } catch (e) {
      // If Supabase is not initialized (e.g., in tests), return false
      return false;
    }
  }

  List<Task> _overdueTasks = [];
  List<Task> _upcomingTasks = [];
  List<Task> _completedTasks = [];
  List<Task> _dismissedTasks = [];
  bool _isLoading = false;
  DateTimeRange? _dateRange;
  bool _resolvedShowCompleted = true;
  int _resolvedDays = 60;
  bool _resolvedShowDismissed = false;
  List<String> _parentRequirementLevels = [];
  int _dateStartOffsetDays = -7;
  int _dateEndOffsetDays = 30;
  int _overdueGraceDays = 14;

  // Computed property that combines overdue and upcoming tasks for backward compatibility
  List<Task> get tasks => [..._overdueTasks, ..._upcomingTasks];
  List<Task> get overdueTasks => _overdueTasks;
  List<Task> get upcomingTasks => _upcomingTasks;
  List<Task> get completedTasks => _completedTasks;
  List<Task> get dismissedTasks => _dismissedTasks;
  bool get isLoading => _isLoading;
  bool get resolvedShowCompleted => _resolvedShowCompleted;
  int get resolvedDays => _resolvedDays;
  bool get resolvedShowDismissed => _resolvedShowDismissed;
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

  void setOverdueGraceDays(int days) {
    _overdueGraceDays = days;
    notifyListeners();
  }

  void setResolvedShowCompleted(bool show) {
    _resolvedShowCompleted = show;
    notifyListeners();
  }

  void setResolvedDays(int days) {
    _resolvedDays = days;
    notifyListeners();
  }

  void setResolvedShowDismissed(bool show) {
    _resolvedShowDismissed = show;
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // First, get user preferences
      final prefs = await Supabase.instance.client
          .from('preferences')
          .select(
              'parent_requirement_levels, date_start_offset_days, date_end_offset_days, overdue_grace_days, resolved_show_completed, resolved_days, resolved_show_dismissed')
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        _parentRequirementLevels =
            List<String>.from(prefs['parent_requirement_levels'] ?? []);
        _dateStartOffsetDays = prefs['date_start_offset_days'] ?? -7;
        _dateEndOffsetDays = prefs['date_end_offset_days'] ?? 30;
        _overdueGraceDays = prefs['overdue_grace_days'] ?? 14;
        _resolvedShowCompleted = prefs['resolved_show_completed'] ?? true;
        _resolvedDays = prefs['resolved_days'] ?? 60;
        _resolvedShowDismissed = prefs['resolved_show_dismissed'] ?? false;
      }

      // Fetch all sections in parallel
      await Future.wait([
        _fetchOverdueTasks(),
        _fetchUpcomingTasks(),
        if (_resolvedShowCompleted || _resolvedShowDismissed)
          _fetchResolvedTasks(),
      ]);

      if (!(_resolvedShowCompleted || _resolvedShowDismissed)) {
        _completedTasks = [];
        _dismissedTasks = [];
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

  Future<void> _fetchResolvedTasks() async {
    try {
      final now = DateTime.now();

      // Fetch completed tasks if enabled
      if (_resolvedShowCompleted) {
        var completedQuery = Supabase.instance.client
            .from('user_tasks')
            .select()
            .eq('state', 'COMPLETED');

        // Only add date filter if not "All" (represented by -1)
        if (_resolvedDays != -1) {
          final completedThreshold =
              now.subtract(Duration(days: _resolvedDays));
          completedQuery = completedQuery.gte(
              'completed_at', completedThreshold.toIso8601String());
        }

        if (_parentRequirementLevels.isNotEmpty) {
          completedQuery = completedQuery.inFilter(
              'parent_requirement_level', _parentRequirementLevels);
        }

        final completedResponse =
            await completedQuery.order('completed_at', ascending: false);

        _completedTasks = (completedResponse as List)
            .map((item) => Task.fromJson(item))
            .toList();
      } else {
        _completedTasks = [];
      }

      // Fetch dismissed tasks if enabled
      if (_resolvedShowDismissed) {
        var dismissedQuery = Supabase.instance.client
            .from('user_tasks')
            .select()
            .eq('state', 'DISMISSED');

        // Only add date filter if not "All" (represented by -1)
        if (_resolvedDays != -1) {
          final dismissedThreshold =
              now.subtract(Duration(days: _resolvedDays));
          dismissedQuery = dismissedQuery.gte(
              'dismissed_at', dismissedThreshold.toIso8601String());
        }

        if (_parentRequirementLevels.isNotEmpty) {
          dismissedQuery = dismissedQuery.inFilter(
              'parent_requirement_level', _parentRequirementLevels);
        }

        final dismissedResponse =
            await dismissedQuery.order('dismissed_at', ascending: false);

        _dismissedTasks = (dismissedResponse as List)
            .map((item) => Task.fromJson(item))
            .toList();
      } else {
        _dismissedTasks = [];
      }
    } catch (e) {
      debugPrint('Error fetching resolved tasks: $e');
      _completedTasks = [];
      _dismissedTasks = [];
    }
  }

  void removeTask(String taskId) {
    _overdueTasks.removeWhere((task) => task.id == taskId);
    _upcomingTasks.removeWhere((task) => task.id == taskId);
    _completedTasks.removeWhere((task) => task.id == taskId);
    _dismissedTasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  void addTask(Task task) {
    // Remove from all lists first to avoid duplicates
    removeTask(task.id);

    // Add to appropriate list based on task state and date
    if (task.state == 'COMPLETED') {
      _completedTasks.add(task);
    } else if (task.state == 'DISMISSED') {
      _dismissedTasks.add(task);
    } else {
      // For OPEN or SNOOZED tasks, add based on date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final effectiveDueDate = task.dueDate ?? task.createdAt;
      final taskDay = DateTime(
          effectiveDueDate.year, effectiveDueDate.month, effectiveDueDate.day);

      if (taskDay.isBefore(today)) {
        // Check if within grace period for overdue
        final graceThreshold =
            today.subtract(Duration(days: _overdueGraceDays));
        if (!taskDay.isBefore(graceThreshold)) {
          _overdueTasks.add(task);
        }
      } else {
        _upcomingTasks.add(task);
      }
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

  void setParentRequirementLevels(List<String> levels) {
    _parentRequirementLevels = List<String>.from(levels);
    notifyListeners();
  }

  Future<void> saveParentRequirementLevels() async {
    if (!_shouldPerformDatabaseOperations) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('preferences').upsert({
        'user_id': userId,
        'parent_requirement_levels': _parentRequirementLevels,
      });
    } catch (e) {
      debugPrint('Error saving parent requirement levels: $e');
    }
  }

  Future<void> _saveDateOffsetPreferences() async {
    if (!_shouldPerformDatabaseOperations) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('preferences').upsert({
        'user_id': userId,
        'date_start_offset_days': _dateStartOffsetDays,
        'date_end_offset_days': _dateEndOffsetDays,
      });
    } catch (e) {
      debugPrint('Error saving date offset preferences: $e');
    }
  }

  Future<void> saveOverdueGraceDays() async {
    if (!_shouldPerformDatabaseOperations) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('preferences').upsert({
        'user_id': userId,
        'overdue_grace_days': _overdueGraceDays,
      });
    } catch (e) {
      debugPrint('Error saving overdue grace days: $e');
    }
  }

  Future<void> saveResolvedPreferences() async {
    if (!_shouldPerformDatabaseOperations) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('preferences').upsert({
        'user_id': userId,
        'resolved_show_completed': _resolvedShowCompleted,
        'resolved_days': _resolvedDays,
        'resolved_show_dismissed': _resolvedShowDismissed,
      });
    } catch (e) {
      debugPrint('Error saving resolved preferences: $e');
    }
  }
}
