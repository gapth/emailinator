import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emailinator_flutter/models/app_state.dart';
import 'package:emailinator_flutter/screens/settings_screen.dart';

class FilterBar extends StatelessWidget {
  final VoidCallback? onFiltersChanged;

  const FilterBar({super.key, this.onFiltersChanged});

  String _formatDateRange(DateTimeRange dateRange) {
    final DateFormat formatter = DateFormat('MMM d');
    final start = formatter.format(dateRange.start);
    final end = formatter.format(dateRange.end);

    // If same year, don't repeat it
    if (dateRange.start.year == dateRange.end.year) {
      return '$start – $end';
    } else {
      return '${formatter.format(dateRange.start)} ${dateRange.start.year} – ${formatter.format(dateRange.end)} ${dateRange.end.year}';
    }
  }

  String _formatRequirementLevels(List<String> levels) {
    if (levels.isEmpty) {
      return 'All Requirements';
    }

    // Convert to user-friendly names and sort for consistency
    final friendlyNames = levels.map((level) {
      switch (level) {
        case 'MANDATORY':
          return 'Mandatory';
        case 'OPTIONAL':
          return 'Optional';
        case 'VOLUNTEER':
          return 'Volunteer';
        case 'NONE':
          return 'None';
        default:
          return level;
      }
    }).toList();

    // Sort to ensure consistent display order
    friendlyNames.sort();

    return friendlyNames.join(', ');
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
      onFiltersChanged?.call();
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    onFiltersChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final chips = <Widget>[];

        // Date range chip
        if (appState.dateRange != null) {
          chips.add(
            ActionChip(
              label: Text(_formatDateRange(appState.dateRange!)),
              avatar: const Icon(Icons.date_range, size: 16),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
              onPressed: () => _selectDateRange(context),
            ),
          );
        }

        // Requirement levels chip
        chips.add(
          ActionChip(
            label: Text(_formatRequirementLevels(
                appState.getParentRequirementLevels())),
            avatar: const Icon(Icons.assignment, size: 16),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 12,
            ),
            onPressed: () => _openSettings(context),
          ),
        );

        if (chips.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: chips,
          ),
        );
      },
    );
  }
}
