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

  String _formatResolvedChip(AppState appState) {
    final showCompleted = appState.resolvedShowCompleted;
    final showDismissed = appState.resolvedShowDismissed;

    if (!showCompleted && !showDismissed) {
      return 'Resolved: Off';
    }

    final resolvedDays = appState.resolvedDays;

    if (showCompleted && showDismissed) {
      final daysText = resolvedDays == -1 ? 'All' : '${resolvedDays}d';
      return 'Resolved: Done ✓ + Dismissed × $daysText';
    } else if (showCompleted) {
      final daysText = resolvedDays == -1 ? 'All' : '${resolvedDays}d';
      return 'Resolved: Done ✓ $daysText';
    } else if (showDismissed) {
      final daysText = resolvedDays == -1 ? 'All' : '${resolvedDays}d';
      return 'Resolved: Dismissed × $daysText';
    }

    return 'Resolved: Off';
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

  Future<void> _showResolvedBottomSheet(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    bool showCompleted = appState.resolvedShowCompleted;
    bool showDismissed = appState.resolvedShowDismissed;
    int resolvedDays = appState.resolvedDays;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Resolved Settings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Show Completed toggle
                  CheckboxListTile(
                    title: const Text('Show Completed'),
                    value: showCompleted,
                    onChanged: (bool? value) {
                      setModalState(() {
                        showCompleted = value ?? false;
                      });
                    },
                  ),

                  // Show Dismissed toggle
                  CheckboxListTile(
                    title: const Text('Show Dismissed'),
                    value: showDismissed,
                    onChanged: (bool? value) {
                      setModalState(() {
                        showDismissed = value ?? false;
                      });
                    },
                  ),

                  // Days range selector (applies to both completed and dismissed)
                  if (showCompleted || showDismissed) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, bottom: 8.0),
                      child: Text(
                        'Range: ${resolvedDays == -1 ? 'All' : '${resolvedDays}d'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildDayChip(context, 30, resolvedDays == 30,
                              (selected) {
                            if (selected) {
                              setModalState(() => resolvedDays = 30);
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildDayChip(context, 60, resolvedDays == 60,
                              (selected) {
                            if (selected) {
                              setModalState(() => resolvedDays = 60);
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildDayChip(context, 90, resolvedDays == 90,
                              (selected) {
                            if (selected) {
                              setModalState(() => resolvedDays = 90);
                            }
                          }),
                          const SizedBox(width: 8),
                          _buildDayChip(context, -1, resolvedDays == -1,
                              (selected) {
                            if (selected) {
                              setModalState(() => resolvedDays = -1);
                            }
                          }, label: 'All'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );

    // Update the app state and save the changes
    appState.setResolvedShowCompleted(showCompleted);
    appState.setResolvedDays(resolvedDays);
    appState.setResolvedShowDismissed(showDismissed);

    await appState.saveResolvedPreferences();
    await appState.fetchTasks(); // Refresh tasks with new filter
    onFiltersChanged?.call();
  }

  Widget _buildDayChip(BuildContext context, int days, bool isSelected,
      ValueChanged<bool> onSelected,
      {String? label}) {
    return FilterChip(
      label: Text(label ?? '${days}d'),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
    );
  }

  Future<void> _showOverdueBottomSheet(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    double selectedDays = appState.overdueGraceDays.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overdue Grace Period',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Show overdue tasks in the last ${selectedDays.round()} days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${selectedDays.round()} days',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Slider(
                    value: selectedDays,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    onChanged: (double value) {
                      setModalState(() {
                        selectedDays = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0 days',
                          style: Theme.of(context).textTheme.labelMedium),
                      Text('30 days',
                          style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );

    // Update the app state and save the changes
    appState.setOverdueGraceDays(selectedDays.round());
    await appState.saveOverdueGraceDays();
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

        // Overdue chip
        chips.add(
          ActionChip(
            label: Text('Overdue: ${appState.overdueGraceDays}d'),
            avatar: const Icon(Icons.schedule, size: 16),
            backgroundColor: Colors.red.shade50,
            labelStyle: TextStyle(
              color: Colors.red.shade700,
              fontSize: 12,
            ),
            onPressed: () => _showOverdueBottomSheet(context),
          ),
        );

        // Resolved chip (renamed from History)
        chips.add(
          ActionChip(
            label: Text(_formatResolvedChip(appState)),
            avatar: const Icon(Icons.check_circle_outline, size: 16),
            backgroundColor: (appState.resolvedShowCompleted ||
                    appState.resolvedShowDismissed)
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.surface,
            labelStyle: TextStyle(
              color: (appState.resolvedShowCompleted ||
                      appState.resolvedShowDismissed)
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
            onPressed: () => _showResolvedBottomSheet(context),
          ),
        );

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
