import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class to debounce submissions.
class DebouncedSubmit {
  DebouncedSubmit(
      {this.debounce = const Duration(milliseconds: 800),
      DateTime Function()? now})
      : _now = now ?? DateTime.now;
  final Duration debounce;
  final DateTime Function() _now;
  DateTime? _last;

  bool ready() => _last == null || _now().difference(_last!) >= debounce;

  void mark() => _last = _now();

  void attempt(VoidCallback action, {bool isLoading = false}) {
    if (isLoading) return;
    if (!ready()) return;
    mark();
    action();
  }
}

/// Wrap a button (or any child) so Enter / NumpadEnter triggers onSubmit.
/// Provides optional debounce and disabled handling.
class SubmitOnEnter extends StatelessWidget {
  const SubmitOnEnter({
    super.key,
    required this.child,
    required this.onSubmit,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (intent) {
            if (enabled) onSubmit();
            return null;
          }),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
