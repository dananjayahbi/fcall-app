import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/core/models/call_session.dart';
import 'package:incoming_call/core/models/call_trigger.dart';
import 'package:incoming_call/core/models/caller_profile.dart';
import 'package:incoming_call/data/repositories/settings_repository.dart';
import 'package:incoming_call/services/scheduling/schedule_service.dart';

import 'fakes/build_orchestrator.dart';

/// Spec §4 lifecycle, asserted as an ordered sequence of hardware calls.
///
/// These tests deliberately assert the **order** of bridge calls, not just the
/// final state. The ordering requirements are the ones that matter on a real
/// handset: releasing the proximity lock after the call is written leaves the
/// panel dark with a logged call, and stopping the ringer after proximity
/// starts produces an audible blip on answer. A state-only assertion passes
/// with either ordering.
void main() {
  const CallerProfile profile = CallerProfile(
    name: 'Dr. Silva',
    number: '0771234567',
  );

  group('Module 2 — scheduling', () {
    test('a future trigger registers an exact alarm', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);

      final ScheduleResult result = await h.orchestrator.arm(
        profile: profile,
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 1)),
      );

      expect(result.ok, isTrue);
      expect(h.bridge.calls, contains('scheduleExactAlarm'));
      expect(h.orchestrator.isArmed, isTrue);
    });

    test('a trigger already in the past is refused with a user-facing reason', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);

      final ScheduleResult result = await h.orchestrator.arm(
        profile: profile,
        trigger: CallTrigger.exact(
          DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('already passed'));
      // The refusal must happen BEFORE the platform is touched — an alarm
      // registered in the past fires instantly, which is a surprise call.
      expect(h.bridge.calls, isNot(contains('scheduleExactAlarm')));
    });

    test('missing exact-alarm permission is reported, not swallowed', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      h.bridge.canSchedule = false;

      final ScheduleResult result = await h.orchestrator.arm(
        profile: profile,
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 1)),
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('Alarms & reminders'));
      expect(h.orchestrator.isArmed, isFalse);
    });

    test('arming persists the profile so the quick trigger can reuse it', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);

      await h.orchestrator.arm(
        profile: profile,
        trigger: CallTrigger.countdown(delay: const Duration(seconds: 15)),
      );
      final ScheduleResult quick = await h.orchestrator.armQuickAction();

      expect(quick.ok, isTrue);
      // The second arm must carry the stored number, not an empty one.
      expect(h.bridge.lastPayload?['number'], '0771234567');
      expect(h.bridge.lastPayload?['name'], 'Dr. Silva');
    });
  });

  group('Module 3/4 — ringing', () {
    test('ringing applies the lock-screen takeover before starting the ringer', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);

      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );

      expect(h.orchestrator.session?.phase, CallPhase.ringing);
      expect(
        h.bridge.indexOf('setLockScreenTakeover:true'),
        lessThan(h.bridge.indexOf('startRinger:true')),
        reason: 'the panel must be woken before the ringer starts, or the '
            'user hears a phone ring with a dark screen',
      );
      expect(h.bridge.calls, contains('setVoiceCommunicationMode:true'));
    });

    test('a volume key silences the ringer but leaves the call ringing', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );

      await h.orchestrator.onVolumeKeyPressed();

      expect(h.bridge.calls, contains('silenceRinger'));
      // Module 4: the call screen must survive the mute.
      expect(h.orchestrator.session?.phase, CallPhase.ringing);
      expect(h.orchestrator.session?.ringerSilenced, isTrue);
    });

    test('a second volume key does NOT resume the ringer', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );

      await h.orchestrator.onVolumeKeyPressed();
      h.bridge.calls.clear();
      await h.orchestrator.onVolumeKeyPressed();

      // One press is a mute, not a toggle. Resuming on a second press is
      // exactly the "fake" tell this app exists to avoid.
      expect(h.bridge.calls, isNot(contains('silenceRinger')));
    });
  });

  group('Module 5 — active call', () {
    test('answering stops the ringer BEFORE engaging proximity', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      h.bridge.calls.clear();

      await h.orchestrator.answer();

      expect(h.orchestrator.session?.phase, CallPhase.active);
      expect(
        h.bridge.indexOf('stopRinger'),
        lessThan(h.bridge.indexOf('startProximityMonitoring')),
        reason: 'Module 5 requires the ringer to terminate instantly; if the '
            'display is already off the user cannot perceive the stop',
      );
    });

    test('proximity NEAR/FAR is surfaced and re-stops teardown', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await h.orchestrator.answer();

      final List<bool> seen = <bool>[];
      final sub = h.orchestrator.proximity.nearStream.listen(seen.add);
      addTearDown(sub.cancel);

      h.bridge.pushProximity(true);
      await Future<void>.delayed(Duration.zero);
      h.bridge.pushProximity(false);
      await Future<void>.delayed(Duration.zero);

      expect(seen, <bool>[true, false]);
      expect(h.orchestrator.proximity.isNear, isFalse);
    });

    test('hanging up releases every hardware resource exactly once', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await h.orchestrator.answer();
      h.bridge.calls.clear();

      await h.orchestrator.hangUp();

      expect(h.orchestrator.session?.phase, CallPhase.ended);
      expect(h.orchestrator.session?.resolution, CallResolution.answered);
      expect(h.bridge.countOf('stopRinger'), 1);
      expect(h.bridge.countOf('stopProximityMonitoring'), 1);
      expect(h.bridge.calls, contains('setKeepScreenOn:false'));
      expect(h.bridge.calls, contains('setVoiceCommunicationMode:false'));
      expect(h.bridge.calls, contains('setLockScreenTakeover:false'));
      expect(h.bridge.calls, contains('hideOverlay'));
    });

    test('a second hang-up is a no-op (no double call-log row)', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await h.orchestrator.answer();
      await h.orchestrator.hangUp();
      h.bridge.calls.clear();

      final second = await h.orchestrator.hangUp();

      expect(second, isNull);
      expect(h.bridge.countOf('writeNativeCallLog'), 0);
    });
  });

  group('Module 6 — call log', () {
    test('an answered call records the real duration', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.persistSettings(
        const AppSettings(vibrate: true, logCalls: true),
      );
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await h.orchestrator.answer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await h.orchestrator.hangUp();

      final entry = h.bridge.lastCallLogEntry;
      expect(entry, isNotNull);
      expect(entry!['number'], '0771234567');
      expect(entry['cachedName'], 'Dr. Silva');
      expect(entry['resolution'], 'answered');
      expect(entry['durationSeconds'], 1);
    });

    test('a declined call records 0 duration, not the ring time', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      await h.orchestrator.decline();

      final entry = h.bridge.lastCallLogEntry;
      expect(entry!['resolution'], 'declined');
      // The ring lasted >1s. Recording that as a "duration" would render as a
      // 1-minute-plus answered call in the dialer.
      expect(entry['durationSeconds'], 0);
    });

    test('logging off means no write at all', () async {
      final TestHarness h = TestHarness();
      addTearDown(h.dispose);
      await h.orchestrator.persistSettings(const AppSettings(logCalls: false));
      await h.orchestrator.beginRinging(
        name: 'Dr. Silva',
        number: '0771234567',
      );
      await h.orchestrator.answer();
      h.bridge.calls.clear();

      await h.orchestrator.hangUp();

      expect(h.bridge.calls, isNot(contains('writeNativeCallLog')));
    });
  });
}
