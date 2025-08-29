import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emailinator_flutter/widgets/submit_on_enter.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets(
      'DebouncedSubmit prevents rapid double submit and allows later one',
      (tester) async {
    int count = 0;
    DateTime current = DateTime(2024, 1, 1, 12, 0, 0, 0);
    final debounced = DebouncedSubmit(
      debounce: const Duration(milliseconds: 500),
      now: () => current,
    );

    void action() => count++;

    debounced.attempt(action, isLoading: false); // first -> count = 1
    debounced.attempt(action, isLoading: false); // ignored -> still 1
    expect(count, 1);
    // Advance virtual time beyond debounce
    current = current.add(const Duration(milliseconds: 600));
    debounced.attempt(action, isLoading: false); // allowed -> count = 2
    expect(count, 2);
  });

  testWidgets('SubmitOnEnter triggers on Enter key', (tester) async {
    int submits = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SubmitOnEnter(
          onSubmit: () => submits++,
          child: const Text('Child'),
        ),
      ),
    ));

    // Send Enter key.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submits, 1);
  });
}
