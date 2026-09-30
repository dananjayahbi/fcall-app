import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The caller name must survive from the moment a schedule is armed to the
/// moment the ring screen is drawn.
///
/// ## Why this is checked statically
///
/// The bug — every saved contact ringing as "Unknown" — lived entirely in
/// Kotlin. Two readers consume the same payload at two different moments:
///
///  * `IncomingCallService` reads it **before** deleting the consumed schedule
///  * `LaunchSignalRelay` reads it **after**, when the full-screen intent lands
///
/// Nothing in Dart or in the build can observe that, and a test would need a
/// real `BroadcastReceiver` + `AlarmManager` to reproduce it. So these read the
/// source and assert the ordering and the id-threading that make it correct.
void main() {
  final File service = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/service/IncomingCallService.kt',
  );
  final File relay = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/platform/LaunchSignalRelay.kt',
  );
  final File resolver = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/platform/CallPayloadResolver.kt',
  );
  final File activeStore = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/platform/ActiveCallStore.kt',
  );

  group('the payload outlives the schedule it came from', () {
    test('the service parks the payload before removing the schedule', () {
      final String source = service.readAsStringSync();
      final int park = source.indexOf('ActiveCallStore.put');
      final int remove = source.indexOf('ScheduleStore.remove');

      expect(
        park,
        greaterThanOrEqualTo(0),
        reason: 'The delivered call must be parked in ActiveCallStore.',
      );
      expect(
        remove,
        greaterThanOrEqualTo(0),
        reason: 'The consumed schedule must still be removed.',
      );
      expect(
        park,
        lessThan(remove),
        reason:
            'Deleting the schedule first is the exact defect: the ring screen '
            're-reads the payload by id afterwards and finds nothing, so every '
            'saved contact rings as "Unknown".',
      );
    });

    test('the active slot carries the schedule id, not just the fields', () {
      // Without the id, a second call firing while the first is on screen could
      // be resolved against the first caller's details.
      expect(
        activeStore.readAsStringSync(),
        contains('scheduleId'),
        reason: 'ActiveCallStore must record which call it holds.',
      );
      expect(
        service.readAsStringSync(),
        contains('"scheduleId" to scheduleId'),
        reason: 'The parked payload must include the id it belongs to.',
      );
    });

    test('the active call is released when the call ends', () {
      final String source = service.readAsStringSync();
      // Otherwise a later call resolved against a previous caller.
      expect(
        RegExp('ActiveCallStore\\.clear').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason:
            'ActiveCallStore must be cleared on both teardown and onDestroy — '
            'one path alone leaves the payload behind on the other.',
      );
    });
  });

  group('the notification path carries the schedule id', () {
    test('buildNotification receives the real id, not an empty string', () {
      final String source = service.readAsStringSync();
      // Regression: the notification used to hard-code "" for the id. On an
      // unlocked handset the notification IS the presentation, so tapping it
      // opened a ring screen with no way to identify the call.
      //
      // Anchored on the *call site* (`val notification = ...`), not on the
      // signature: a substring check that matched the parameter list would keep
      // passing even with the call site broken, which is precisely the mistake
      // that made this test green against a real defect.
      final RegExpMatch? call = RegExp(
        r'val notification\s*=\s*buildNotification\(([^)]*)\)',
      ).firstMatch(source);

      expect(
        call,
        isNotNull,
        reason: 'Could not find the buildNotification call site.',
      );
      final String args = call!.group(1)!;
      expect(
        args,
        contains('scheduleId'),
        reason:
            'The call site must pass the real schedule id. Passing "" means the '
            'unlocked path (heads-up notification tap) cannot identify the call, '
            'so it rings as "Unknown".',
      );
      expect(
        args,
        isNot(contains('""')),
        reason: 'An empty-string id in the notification PendingIntent is the defect.',
      );
    });
  });

  group('the resolver prefers the payload the service is ringing from', () {
    test('the active store is consulted first', () {
      final String source = resolver.readAsStringSync();
      final int active = source.indexOf('ActiveCallStore.readPayload');
      final int scheduled = source.indexOf('ScheduleStore.readOne');
      final int legacy = source.indexOf('CallSessionStore.readPayload');

      expect(active, greaterThanOrEqualTo(0));
      expect(scheduled, greaterThanOrEqualTo(0));
      expect(
        active,
        lessThan(scheduled),
        reason: 'The call in progress outranks a still-pending schedule.',
      );
      expect(scheduled, lessThan(legacy));
    });

    test('a stale active payload for another call is not preferred', () {
      // Two calls back to back: without this guard, call #2 would be announced
      // with call #1's caller.
      expect(
        resolver.readAsStringSync(),
        contains('matches(active, scheduleId)'),
        reason:
            'The resolver must verify the active payload belongs to the firing '
            'schedule id before preferring it over a store lookup.',
      );
    });
  });

  group('the relay prefers the intent extras', () {
    test('the caller is read from the intent before any store', () {
      final String source = relay.readAsStringSync();
      final int readCaller = source.indexOf('readCaller(intent)');
      final int resolve = source.indexOf('CallPayloadResolver.resolve');

      expect(
        readCaller,
        greaterThanOrEqualTo(0),
        reason: 'The relay must read the caller carried by the intent.',
      );
      expect(
        readCaller,
        lessThan(resolve),
        reason:
            'Extras placed by the ringing service cannot be stale or already '
            'consumed, so they outrank any persisted lookup.',
      );
    });

    test('a missing name is distinguishable from a blank name', () {
      // Returning an empty map for a nameless contact would send the caller
      // into the store-lookup path and show a different name than the
      // notification.
      expect(
        relay.readAsStringSync(),
        contains('if (name == null && number == null) return null'),
      );
    });
  });
}
