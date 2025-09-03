import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emailinator_flutter/models/app_state.dart';

class FilterBar extends StatelessWidget {
  final VoidCallback? onFiltersChanged;

  const FilterBar({super.key, this.onFiltersChanged});

  String _formatRequirementLevels(List<String> levels) {
    final allLevels = ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'];

    if (levels.isEmpty || levels.length == allLevels.length) {
      return 'All';
    }

    // Convert to single letter codes
    final codes = <String>[];
    if (levels.contains('MANDATORY')) codes.add('M');
    if (levels.contains('OPTIONAL')) codes.add('O');
    if (levels.contains('VOLUNTEER')) codes.add('V');
    if (levels.contains('NONE')) codes.add('N');

    return codes.join(' ');
  }

  String _formatCountWithCap(int count) {
    return count > 99 ? '99+' : count.toString();
  }

  String _formatResolvedChip(AppState appState) {
    final showCompleted = appState.resolvedShowCompleted;
    final showDismissed = appState.resolvedShowDismissed;
    final completedCount = appState.completedTasks.length;
    final dismissedCount = appState.dismissedTasks.length;

    final parts = <String>[];

    if (showCompleted && completedCount > 0) {
      parts.add('✓${_formatCountWithCap(completedCount)}');
    }

    if (showDismissed && dismissedCount > 0) {
      parts.add('×${_formatCountWithCap(dismissedCount)}');
    }

    if (parts.isEmpty) {
      return 'None';
    }

    return parts.join(' ');
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

  String _getOverdueTooltip(AppState appState) {
    return 'last ${appState.overdueGraceDays} days';
  }

  String _getUpcomingTooltip(AppState appState) {
    return 'next ${appState.upcomingDays} days';
  }

  String _getResolvedTooltip(AppState appState) {
    final showCompleted = appState.resolvedShowCompleted;
    final showDismissed = appState.resolvedShowDismissed;

    final parts = <String>[];
    if (showCompleted) parts.add('✓ Completed');
    if (showDismissed) parts.add('× Dismissed');

    if (parts.isEmpty) return 'None shown';
    return parts.join(', ');
  }

  String _getRequirementTooltip(AppState appState) {
    final levels = appState.getParentRequirementLevels();
    final allLevels = ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'];

    if (levels.isEmpty || levels.length == allLevels.length) {
      return 'All requirement levels';
    }

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

    return friendlyNames.join(', ');
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

  Future<void> _showUpcomingBottomSheet(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    double selectedDays = appState.upcomingDays.toDouble();

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
                        'Upcoming days',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show upcoming tasks in the next ${selectedDays.round()} days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${selectedDays.round()} days',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Slider(
                    value: selectedDays,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (double value) {
                      setModalState(() {
                        selectedDays = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 day',
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
    appState.setUpcomingDays(selectedDays.round());
    await appState.saveUpcomingDays();
    await appState.fetchTasks(); // Refresh tasks with new filter
    onFiltersChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final chips = <Widget>[];

        // 1) Overdue chip - Always shown
        final overdueCount = appState.overdueTasks.length;
        chips.add(
          Tooltip(
            message: _getOverdueTooltip(appState),
            child: ActionChip(
              label: Text(_formatCountWithCap(overdueCount)),
              avatar: const Icon(Icons.error_outline, size: 16),
              backgroundColor: Colors.red.shade50,
              labelStyle: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
              onPressed: () => _showOverdueBottomSheet(context),
            ),
          ),
        );

        // 2) Upcoming chip - Always shown with task count
        final upcomingCount = appState.upcomingTasks.length;
        chips.add(
          Tooltip(
            message: _getUpcomingTooltip(appState),
            child: ActionChip(
              label: Text(_formatCountWithCap(upcomingCount)),
              avatar: const Icon(Icons.calendar_month, size: 16),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
              onPressed: () => _showUpcomingBottomSheet(context),
            ),
          ),
        );

        // 3) Resolved settings - Always shown
        final resolvedText = _formatResolvedChip(appState);
        chips.add(
          Tooltip(
            message: _getResolvedTooltip(appState),
            child: ActionChip(
              label: Text(resolvedText),
              avatar: const Icon(Icons.done_all, size: 16),
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
          ),
        );

        // 4) Requirement filter - Always shown
        final requirementText =
            _formatRequirementLevels(appState.getParentRequirementLevels());
        chips.add(
          Tooltip(
            message: _getRequirementTooltip(appState),
            child: ActionChip(
              label: Text(requirementText),
              avatar: const Icon(Icons.filter_alt, size: 16),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontSize: 12,
              ),
              onPressed: () => _showParentRequirementBottomSheet(context),
            ),
          ),
        );

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
