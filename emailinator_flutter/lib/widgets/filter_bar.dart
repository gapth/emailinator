import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emailinator_flutter/models/app_state.dart';

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
    final allLevels = ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'];

    if (levels.isEmpty || levels.length == allLevels.length) {
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
    final initialDateRange =
        appState.dateRange ?? appState.getDefaultDateRange();

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

  Future<void> _showParentRequirementBottomSheet(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final allLevels = ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'];
    List<String> selectedLevels =
        List<String>.from(appState.getParentRequirementLevels());

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Parent Requirement Levels',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...allLevels.map((level) {
                    return CheckboxListTile(
                      title: Text(level),
                      value: selectedLevels.contains(level),
                      onChanged: (bool? value) {
                        setModalState(() {
                          if (value == true) {
                            selectedLevels.add(level);
                          } else {
                            selectedLevels.remove(level);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );

    // Update the app state and save the changes
    appState.setParentRequirementLevels(selectedLevels);
    await appState.saveParentRequirementLevels();
    await appState.fetchTasks(); // Refresh tasks with new filter
    onFiltersChanged?.call();
  }

  Future<void> _toggleHistory(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setShowHistory(!appState.showHistory);
    await appState.saveHistoryPreference();
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
            onPressed: () => _showParentRequirementBottomSheet(context),
          ),
        );

        // History toggle chip
        chips.add(
          FilterChip(
            label: const Text('History'),
            avatar: const Icon(Icons.history, size: 16),
            selected: appState.showHistory,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedColor: Theme.of(context).colorScheme.tertiaryContainer,
            checkmarkColor: Theme.of(context).colorScheme.onTertiaryContainer,
            labelStyle: TextStyle(
              color: appState.showHistory
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
            onSelected: (selected) => _toggleHistory(context),
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
