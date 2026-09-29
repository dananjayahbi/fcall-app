import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/core/models/call_trigger.dart';
import 'package:incoming_call/features/home/widgets/relative_delay_card.dart';

/// Task 3 — the hand-entered minutes/hours control.
///
/// Driven through real taps rather than a synthetic pointer at computed
/// coordinates: the unit toggle is a `GestureDetector`, which Flutter's
/// semantics tree does not surface as a plain button, so a coordinate-based
/// click in a browser can silently miss it. `tester.tap` exercises the same
/// gesture handler the device does.
void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  Future<(RelativeUnit, int)> pumpAndTap(
    WidgetTester tester,
    String unitLabel,
  ) async {
    late RelativeUnit unit;
    late int value;
    await tester.pumpWidget(
      wrap(
        RelativeDelayCard(
          onChanged: (RelativeUnit u, int v) {
            unit = u;
            value = v;
          },
        ),
      ),
    );
    await tester.tap(find.text(unitLabel));
    await tester.pumpAndSettle();
    return (unit, value);
  }

  testWidgets('defaults to minutes with the preset value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(RelativeDelayCard(onChanged: (_, _) {})),
    );
    expect(find.text('min'), findsOneWidget);
    expect(find.text('Rings in 10 min from now'), findsOneWidget);
  });

  testWidgets('tapping hr switches the unit and re-states the value in hours', (
    WidgetTester tester,
  ) async {
    final (RelativeUnit unit, int value) = await pumpAndTap(tester, 'hr');

    expect(unit, RelativeUnit.hours);
    // The number is reinterpreted, not converted: 10 stays 10.
    expect(value, 10);
    expect(find.text('Rings in 10 hr from now'), findsOneWidget);
  });

  testWidgets('the preview never mixes units', (
    WidgetTester tester,
  ) async {
    // Regression: the preview used to render `.inMinutes` unconditionally, so
    // choosing hours printed "600 min" under a control reading "2 hr".
    await pumpAndTap(tester, 'hr');
    final String text = tester.widget<Text>(find.textContaining('Rings in')).data!;
    expect(text, contains('hr'));
    expect(text, isNot(contains('min')));
  });

  testWidgets('typing a value reports it and updates the preview', (
    WidgetTester tester,
  ) async {
    int? reported;
    await tester.pumpWidget(
      wrap(RelativeDelayCard(onChanged: (_, int v) => reported = v)),
    );

    await tester.enterText(find.byType(TextField), '45');
    await tester.pumpAndSettle();

    expect(reported, 45);
    expect(find.text('Rings in 45 min from now'), findsOneWidget);
  });

  testWidgets('an empty field is clamped to 1 rather than firing instantly', (
    WidgetTester tester,
  ) async {
    int? reported;
    await tester.pumpWidget(
      wrap(RelativeDelayCard(onChanged: (_, int v) => reported = v)),
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(reported, 1);
  });

  testWidgets('non-numeric input is rejected by the formatter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(RelativeDelayCard(onChanged: (_, _) {})));

    await tester.enterText(find.byType(TextField), '12abc');
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
  });
}
