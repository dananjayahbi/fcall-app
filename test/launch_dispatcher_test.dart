import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/core/models/call_session.dart';
import 'package:incoming_call/core/models/caller_profile.dart';
import 'package:incoming_call/services/launch_dispatcher.dart';

import 'fakes/build_orchestrator.dart';

/// Module 2/3 — the native → Dart launch signal.
///
/// ## Why this file exists
///
/// Three of the four defects behind "I pressed Quick trigger and nothing
/// happened" / "it rang but no ring screen appeared" all lived on this one
/// seam, and none of them were reachable from the existing tests:
///
///  1. the `incomingcall/launch` EventChannel had no native registration, so
///     `launchTriggerStream` never emitted a single event;
///  2. `consumeLaunchIntent` returned `launchSource`/`autoRing` while both
///     consumers test for `event == 'quickRing'`, so the payload matched
///     nothing and was silently dropped;
///  3. a second quick trigger could arm a second alarm on top of the first,
///     because the launcher shortcut re-arms with a fixed 10s delay and
///     nothing cancels a pending one.
///
/// A test that builds its expected event name from the *dispatcher's own*
/// constant would agree with a wrong implementation, so every event name here
/// is written as a literal string. The literals are what the Kotlin side
/// (`LaunchSignalRelay`) actually sends.
void main() {
  const CallerProfile profile = CallerProfile(
    name: 'Dr. Silva',
    number: '0771234567',
  );

  group('callIncoming — the alarm reached Dart', () {
    test('a callIncoming event brings the ring screen up', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{
        'event': 'callIncoming',
        'name': 'Dr. Silva',
        'number': '0771234567',
        'simLabel': 'SIM 1',
      });
      await pumpEventQueue();

      // The regression: an unhandled event leaves the phase at `idle`, so the
      // app never leaves HomePage and no ring screen is ever built.
      expect(h.orchestrator.session?.phase, CallPhase.ringing);
      expect(h.orchestrator.session?.profileName, 'Dr. Silva');
      expect(h.orchestrator.isInCall, isTrue);
    });

    test('a callIncoming event actually starts the ringer', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{
        'event': 'callIncoming',
        'name': 'Dr. Silva',
        'number': '0771234567',
      });
      await pumpEventQueue();

      expect(h.bridge.countOf('startRinger'), 1);
      // The takeover must be armed before the ringer starts, otherwise the
      // screen is still locked when the first ringtone plays.
      expect(
        h.bridge.indexOf('setLockScreenTakeover:true'),
        lessThan(h.bridge.indexOf('startRinger:true')),
      );
    });

    test('a missing number does not throw and still shows the call', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      // No 'name'/'number'/'simLabel' at all. A cast-based implementation
      // throws on `(event[key] ?? '') as String` for a null; the contract is
      // that a missing capability degrades, never throws mid-call.
      h.bridge.emitLaunch(<String, dynamic>{'event': 'callIncoming'});
      await pumpEventQueue();

      expect(h.orchestrator.session?.phase, CallPhase.ringing);
    });

    test('a non-string name is coerced rather than crashing the call', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{
        'event': 'callIncoming',
        'name': 42,
        'number': '0771234567',
      });
      await pumpEventQueue();

      expect(h.orchestrator.session?.profileName, '42');
    });
  });

  group('quickRing — the quick trigger reached Dart', () {
    test('a quickRing event arms a countdown', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.persistProfile(profile);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{'event': 'quickRing'});
      await pumpEventQueue();

      expect(h.orchestrator.isArmed, isTrue);
      expect(h.bridge.calls, contains('scheduleExactAlarm'));
    });

    test('a second quick trigger supersedes the first rather than stacking', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.persistProfile(profile);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{'event': 'quickRing'});
      await pumpEventQueue();
      h.bridge.emitLaunch(<String, dynamic>{'event': 'quickRing'});
      await pumpEventQueue();

      expect(h.orchestrator.isArmed, isTrue);

      // Two live alarms would fire the call twice, minutes apart. The invariant
      // is "one live alarm at a time", i.e. every registration after the first
      // is preceded by a cancel — not "schedule is called once", which would
      // forbid a legitimate re-arm.
      final int scheduled = h.bridge.countOf('scheduleExactAlarm');
      final int cancelled = h.bridge.countOf('cancelExactAlarm');
      expect(scheduled, 2);
      expect(cancelled, scheduled - 1);

      // The cancel must sit *between* the two registrations, proving the first
      // alarm was torn down before the second was set.
      final int firstSchedule = h.bridge.calls.indexOf('scheduleExactAlarm');
      final int cancel = h.bridge.calls.indexOf('cancelExactAlarm');
      final int secondSchedule = h.bridge.calls.lastIndexOf('scheduleExactAlarm');
      expect(cancel, greaterThan(firstSchedule));
      expect(cancel, lessThan(secondSchedule));
    });

    test('an unknown event is ignored without touching the call flow', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{'event': 'somethingElse'});
      await pumpEventQueue();

      expect(h.orchestrator.session, isNull);
      expect(h.bridge.calls, isEmpty);
    });

    test('an event with no discriminator is ignored, not a crash', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{'name': 'no event key'});
      await pumpEventQueue();

      expect(h.orchestrator.session, isNull);
    });
  });

  group('volumeKey', () {
    test('a volume key while ringing silences the ringer and keeps the call', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{
        'event': 'callIncoming',
        'name': 'Dr. Silva',
        'number': '0771234567',
      });
      await pumpEventQueue();

      h.bridge.emitLaunch(<String, dynamic>{'event': 'volumeKeyPressed'});
      await pumpEventQueue();

      expect(h.bridge.countOf('silenceRinger'), 1);
      // The call must survive the mute — that is the specified behaviour.
      expect(h.orchestrator.session?.phase, CallPhase.ringing);
      expect(h.orchestrator.session?.ringerSilenced, isTrue);
    });

    test('a volume key with no call in progress is a no-op', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{'event': 'volumeKeyPressed'});
      await pumpEventQueue();

      expect(h.bridge.countOf('silenceRinger'), 0);
    });
  });

  group('event-name contract with the native side', () {
    test('the names the dispatcher accepts are the names the relay sends', () {
      // A literal-for-literal guard. `LaunchSignalRelay.Event` in Kotlin holds
      // these three strings; if either side is renamed without the other, this
      // fails here instead of silently dropping every call on a device.
      expect(LaunchDispatcher.eventCall, 'callIncoming');
      expect(LaunchDispatcher.eventQuickRing, 'quickRing');
      expect(LaunchDispatcher.eventVolumeKey, 'volumeKeyPressed');
    });

    test('the payload keys match CallPayloadKeys on the native side', () {
      expect(LaunchDispatcher.keyName, 'name');
      expect(LaunchDispatcher.keyNumber, 'number');
      expect(LaunchDispatcher.keySimLabel, 'simLabel');
      expect(LaunchDispatcher.keyEvent, 'event');
    });
  });

  group('subscribe-once', () {
    test('start() twice does not double-subscribe and ring twice', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.dispatcher.start();
      h.dispatcher.start();

      h.bridge.emitLaunch(<String, dynamic>{
        'event': 'callIncoming',
        'name': 'Dr. Silva',
        'number': '0771234567',
      });
      await pumpEventQueue();

      expect(h.bridge.countOf('startRinger'), 1);
    });
  });
}
