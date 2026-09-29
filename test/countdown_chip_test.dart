import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/widgets/countdown_chip.dart';

/// Task 4 — a rejected call must stop claiming it is ringing.
///
/// The bug: the chip decided "a call is ringing" purely from the clock running
/// past the fire time, so after declining it went on saying **Ringing now**
/// indefinitely. Only the parent knows what actually happened, so the
/// regression test drives the chip the way the parent does.
void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('a pending call counts down', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        CountdownChip(fireAt: DateTime.now().add(const Duration(minutes: 5))),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Incoming call in'), findsOneWidget);
    expect(find.text('Ringing now'), findsNothing);
  });

  testWidgets('a call in progress does not say Ringing now', (
    WidgetTester tester,
  ) async {
    // Fire time in the past AND the call already declined.
    await tester.pumpWidget(
      wrap(
        CountdownChip(
          fireAt: DateTime.now().subtract(const Duration(minutes: 2)),
          completed: true,
          completedLabel: 'Call ended',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ringing now'), findsNothing);
    expect(find.text('Call ended'), findsOneWidget);
  });

  testWidgets('the terminal state takes precedence over an elapsed clock', (
    WidgetTester tester,
  ) async {
    // This is the exact regression: without `completed`, an elapsed clock alone
    // produced "Ringing now" — which is what the user saw after declining.
    await tester.pumpWidget(
      wrap(
        CountdownChip(
          fireAt: DateTime.now().subtract(const Duration(hours: 1)),
          completed: true,
          completedLabel: 'Declined',
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ringing now'), findsNothing);
    expect(find.text('Declined'), findsOneWidget);
  });

  testWidgets('an elapsed clock alone still reads Ringing now', (
    WidgetTester tester,
  ) async {
    // Guards the other direction: the fix must not suppress the genuine
    // "the call is arriving right now" state, which is correct while the call
    // really is ringing.
    await tester.pumpWidget(
      wrap(
        CountdownChip(fireAt: DateTime.now().subtract(const Duration(seconds: 1))),
      ),
    );
    await tester.pump();

    expect(find.text('Ringing now'), findsOneWidget);
  });

  testWidgets('a completed chip offers Dismiss rather than Cancel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CountdownChip(
          fireAt: DateTime.now(),
          completed: true,
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
