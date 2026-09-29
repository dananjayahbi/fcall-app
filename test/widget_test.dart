import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/app.dart';
import 'package:incoming_call/core/app_scope.dart';
import 'package:incoming_call/core/models/call_session.dart';
import 'package:incoming_call/features/active_call/active_call_page.dart';
import 'package:incoming_call/features/home/home_page.dart';
import 'package:incoming_call/features/incoming_call/incoming_call_page.dart';

import 'fakes/build_orchestrator.dart';

/// Widget-level checks on the phase-driven screen swap.
///
/// The spec's central architectural claim is that the visible screen is a
/// *function of the call phase*, not of a navigation stack. That is what lets a
/// cold start from a `BroadcastReceiver` — with no navigation history at all —
/// land on the same screen. These tests pin that claim.
///
/// Two harness facts worth recording, because both cost real debugging time:
///
///  * `pumpAndSettle` cannot be used once a call is active. The active-call
///    screen runs a 1-second `Timer.periodic` for the call timer, so the tree
///    is never "settled" and `pumpAndSettle` times out. These tests pump a
///    fixed number of frames instead.
///  * Every test injects a fake bridge through [AppScopeFactory.build].
///    Reaching the ambient platform bridge hangs, because a real MethodChannel
///    never completes under `flutter_test`.
void main() {
  AppScope buildScope() {
    final TestHarness harness = TestHarness();
    return AppScopeFactory.build(bridge: harness.bridge, store: harness.store);
  }

  /// Pumps a bounded number of frames so async session events land without
  /// waiting for a tree that never settles.
  Future<void> settleFrames(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Taps the "Answer"/"Decline" action.
  ///
  /// Tapping the rendered text is not enough: the label sits *beside* the
  /// circle in the column, so the gesture misses. The action now carries a
  /// ValueKey and the whole button is one tappable target, so keying on it
  /// exercises the same path a user does.
  Future<void> tapCallAction(WidgetTester tester, String label) async {
    final Finder action = find.byKey(
      ValueKey<String>('${label.toLowerCase()}-action'),
    );
    expect(action, findsOneWidget, reason: 'the $label action must be on screen');
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await tester.pump();
  }

  testWidgets('home is shown while the phase is idle', (
    WidgetTester tester,
  ) async {
    final AppScope scope = buildScope();
    addTearDown(scope.orchestrator.dispose);

    await tester.pumpWidget(IncomingCallApp(scope: scope));
    await tester.pump();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(IncomingCallPage), findsNothing);
  });

  testWidgets('ringing swaps in the incoming-call screen', (
    WidgetTester tester,
  ) async {
    final AppScope scope = buildScope();
    addTearDown(scope.orchestrator.dispose);

    await tester.pumpWidget(IncomingCallApp(scope: scope));
    await tester.pump();

    await scope.orchestrator.beginRinging(
      name: 'Dr. Silva',
      number: '0771234567',
    );
    await settleFrames(tester);

    expect(find.byType(IncomingCallPage), findsOneWidget);
    expect(find.text('Dr. Silva'), findsWidgets);
    expect(find.text('0771234567'), findsWidgets);
    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('Answer'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('tapping Answer replaces the incoming screen with the active one', (
    WidgetTester tester,
  ) async {
    final AppScope scope = buildScope();
    addTearDown(scope.orchestrator.dispose);

    await tester.pumpWidget(IncomingCallApp(scope: scope));
    await tester.pump();
    await scope.orchestrator.beginRinging(
      name: 'Dr. Silva',
      number: '0771234567',
    );
    await settleFrames(tester);
    expect(find.byType(IncomingCallPage), findsOneWidget);

    // Tap the semantic label inside the button, the way a screen reader or a
    // user would. Tapping the raw `Text` misses the GestureDetector, which is
    // on the animated container above it.
    await tapCallAction(tester, 'Answer');
    await settleFrames(tester);

    expect(scope.orchestrator.session?.phase, CallPhase.active);
    expect(find.byType(ActiveCallPage), findsOneWidget);
    expect(find.byType(IncomingCallPage), findsNothing);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);
  });

  testWidgets('declining returns to home and logs a rejected call', (
    WidgetTester tester,
  ) async {
    final AppScope scope = buildScope();
    addTearDown(scope.orchestrator.dispose);

    await tester.pumpWidget(IncomingCallApp(scope: scope));
    await tester.pump();
    await scope.orchestrator.beginRinging(
      name: 'Dr. Silva',
      number: '0771234567',
    );
    await settleFrames(tester);

    await tapCallAction(tester, 'Decline');
    await settleFrames(tester);

    expect(scope.orchestrator.session?.resolution, CallResolution.declined);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(IncomingCallPage), findsNothing);
  });

  group('no internal terminology is visible to the user', () {
    /// Words that would give the game away if they ever appeared on screen.
    const List<String> banned = <String>[
      'simulat', 'fake', 'preview', 'stub', 'headless', 'web', 'test',
    ];

    void expectNoBannedText(WidgetTester tester) {
      final String text = find.byType(Scaffold).evaluate().isEmpty
          ? ''
          : tester
                .widgetList<RichText>(find.byType(RichText))
                .map((RichText r) => r.text.toPlainText())
                .join(' ')
                .toLowerCase();

      for (final String word in banned) {
        expect(
          text.contains(word),
          isFalse,
          reason: 'the word "$word" must never be rendered to the user — the '
              'call screen has to read as an ordinary call alert',
        );
      }
    }

    testWidgets('the config screen is clean', (WidgetTester tester) async {
      final AppScope scope = buildScope();
      addTearDown(scope.orchestrator.dispose);

      await tester.pumpWidget(IncomingCallApp(scope: scope));
      await tester.pump();

      expectNoBannedText(tester);
    });

    testWidgets('the incoming-call screen is clean', (
      WidgetTester tester,
    ) async {
      final AppScope scope = buildScope();
      addTearDown(scope.orchestrator.dispose);

      await tester.pumpWidget(IncomingCallApp(scope: scope));
      await tester.pump();
      await scope.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await settleFrames(tester);

      expectNoBannedText(tester);
    });

    testWidgets('the active-call screen is clean', (WidgetTester tester) async {
      final AppScope scope = buildScope();
      addTearDown(scope.orchestrator.dispose);

      await tester.pumpWidget(IncomingCallApp(scope: scope));
      await tester.pump();
      await scope.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await settleFrames(tester);
      await scope.orchestrator.answer();
      await settleFrames(tester);

      expectNoBannedText(tester);
    });
  });

  testWidgets('the app bar carries the neutral app name', (
    WidgetTester tester,
  ) async {
    final AppScope scope = buildScope();
    addTearDown(scope.orchestrator.dispose);

    await tester.pumpWidget(IncomingCallApp(scope: scope));
    await tester.pump();

    // "Fake Call" in the launcher/app bar is the most obvious give-away.
    expect(find.text('Incoming Call'), findsOneWidget);
    expect(find.text('Fake Call'), findsNothing);
  });
}
