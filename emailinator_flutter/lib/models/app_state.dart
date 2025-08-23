import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emailinator_flutter/models/task.dart';

class AppState extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  DateTimeRange? _dateRange;
  bool _includeNoDueDate = true;
  List<String> _parentRequirementLevels = [];

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Future<void> fetchTasks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      // First, get user preferences
      final prefs = await Supabase.instance.client
          .from('preferences')
          .select('parent_requirement_levels, include_no_due_date')
          .eq('user_id', userId)
          .maybeSingle();

      if (prefs != null) {
        _parentRequirementLevels = List<String>.from(prefs['parent_requirement_levels'] ?? []);
        _includeNoDueDate = prefs['include_no_due_date'] ?? true;
      }

      var query = Supabase.instance.client
          .from('tasks')
          .select()
          .eq('status', 'PENDING');

      if (_parentRequirementLevels.isNotEmpty) {
        query = query.filter('parent_requirement_level', 'in', '(${_parentRequirementLevels.map((l) => "'$l'").join(',')})');
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

    } catch (e) {
      // Handle error
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void removeTask(int taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }
}
