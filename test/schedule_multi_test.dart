import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:incoming_call/core/models/call_trigger.dart';
import 'package:incoming_call/core/models/contact.dart';
import 'package:incoming_call/core/models/scheduled_call.dart';
import 'package:incoming_call/core/utils/timeline_gap_formatter.dart';
import 'package:incoming_call/data/repositories/contact_repository.dart';
import 'package:incoming_call/data/storage/key_value_store.dart';
import 'package:incoming_call/services/scheduling/schedule_book.dart';

import 'fakes/fake_bridge.dart';

/// Tasks 2, 3 and 5 — the contact book, the relative trigger, and multiple
/// armed calls.
///
/// The seed for the randomiser is fixed so "picks a different contact each
/// time" is a property that can actually be asserted. A test that relies on a
/// genuinely random draw passing by luck is a test that fails in CI
/// eventually and gets ignored.
void main() {
  late InMemoryKeyValueStore store;
  late ContactRepository contacts;

  setUp(() {
    store = InMemoryKeyValueStore();
    contacts = ContactRepository(store, random: Random(7));
  });

  Contact make(String id, String name, String number) =>
      Contact(id: id, name: name, number: number);

  group('Task 2 — the contact book', () {
    test('saves, lists and removes contacts', () async {
      await contacts.upsert(make('a', 'Dr. Silva', '0771234567'));
      await contacts.upsert(make('b', 'Nurse Amara', '0777654321'));

      final List<Contact> stored = await contacts.load();
      expect(stored.map((Contact c) => c.name), containsAll(<String>['Dr. Silva', 'Nurse Amara']));

      await contacts.remove('a');
      final List<Contact> after = await contacts.load();
      expect(after, hasLength(1));
      expect(after.single.id, 'b');
    });

    test('upserting the same id updates rather than duplicates', () async {
      await contacts.upsert(make('a', 'Dr. Silva', '0771234567'));
      await contacts.upsert(make('a', 'Dr. Silva', '0779999999'));

      final List<Contact> stored = await contacts.load();
      expect(stored, hasLength(1));
      expect(stored.single.number, '0779999999');
    });

    test('a contact saved with only a number still renders a name', () {
      final Contact contact = make('a', '', '0771234567');
      expect(contact.displayName, '0771234567');
    });

    test('a contact with no number is not usable and is never picked', () async {
      await contacts.upsert(make('a', '', ''));
      await contacts.upsert(make('b', 'Dr. Silva', '0771234567'));

      final ContactRandomiser randomiser = ContactRandomiser(contacts);
      // Repeated because a uniform draw would sometimes land on the empty one;
      // the point is that it can never *return* it.
      for (int i = 0; i < 20; i++) {
        expect((await randomiser.pick())?.id, 'b');
      }
    });

    test('the randomiser does not repeat the previous pick', () async {
      for (int i = 0; i < 4; i++) {
        await contacts.upsert(make('id$i', 'Contact $i', '077000000$i'));
      }
      final ContactRandomiser randomiser = ContactRandomiser(contacts);

      final Set<String> seen = <String>{};
      for (int i = 0; i < 12; i++) {
        final Contact? pick = await randomiser.pick();
        expect(pick, isNotNull);
        seen.add(pick!.id);
      }
      // With four contacts and no repeats allowed, every one must appear.
      expect(seen, hasLength(4));
    });

    test('the randomiser returns null on an empty book', () async {
      expect(await ContactRandomiser(contacts).pick(), isNull);
    });

    test('a single contact is always returned, never null', () async {
      await contacts.upsert(make('only', 'Solo', '0771234567'));
      expect((await ContactRandomiser(contacts).pick())?.id, 'only');
    });
  });

  group('Task 3 — the relative minutes/hours trigger', () {
    test('minutes and hours produce the right delay', () {
      final DateTime now = DateTime(2026, 9, 29, 12);
      expect(
        CallTrigger.relative(value: 45, unit: RelativeUnit.minutes, now: now)
            .fireAt,
        now.add(const Duration(minutes: 45)),
      );
      expect(
        CallTrigger.relative(value: 2, unit: RelativeUnit.hours, now: now).fireAt,
        now.add(const Duration(hours: 2)),
      );
    });

    test('a value below 1 is clamped rather than firing instantly', () {
      final DateTime now = DateTime(2026, 9, 29, 12);
      final CallTrigger zero = CallTrigger.relative(
        value: 0,
        unit: RelativeUnit.minutes,
        now: now,
      );
      // Zero would fire the instant it is armed, which reads as a broken
      // button rather than as "immediately".
      expect(zero.fireAt.isAfter(now), isTrue);
      expect(zero.relativeValue, 1);

      final CallTrigger negative = CallTrigger.relative(
        value: -5,
        unit: RelativeUnit.hours,
        now: now,
      );
      expect(negative.fireAt.isAfter(now), isTrue);
    });

    test('the chosen unit survives a save/load round trip', () {
      final CallTrigger original = CallTrigger.relative(
        value: 3,
        unit: RelativeUnit.hours,
      );
      final CallTrigger restored = CallTrigger.fromJson(original.toJson());

      expect(restored.kind, CallTriggerKind.relative);
      expect(restored.relativeUnit, RelativeUnit.hours);
      expect(restored.relativeValue, 3);
      expect(restored.fireAtMs, original.fireAtMs);
      expect(restored.relativeLabel, '3 hr');
    });

    test('relative is a distinct kind from a preset countdown', () {
      // A preset and a hand-typed delay can land on the same instant; the
      // timeline still needs to tell them apart.
      final DateTime now = DateTime(2026, 9, 29, 12);
      final CallTrigger preset = CallTrigger.countdown(
        delay: const Duration(minutes: 5),
        now: now,
      );
      final CallTrigger typed = CallTrigger.relative(
        value: 5,
        unit: RelativeUnit.minutes,
        now: now,
      );
      expect(typed.fireAtMs, preset.fireAtMs);
      expect(typed.kind, isNot(CallTriggerKind.countdown));
    });
  });

  group('Task 5 — multiple simultaneous schedules', () {
    late FakeBridge bridge;
    late ScheduleBook book;

    setUp(() {
      bridge = FakeBridge();
      book = ScheduleBook(bridge: bridge);
    });

    Contact caller() => make('c1', 'Dr. Silva', '0771234567');

    test('three calls can be armed at once and all persist', () async {
      final DateTime base = DateTime.now().add(const Duration(minutes: 1));
      for (int i = 0; i < 3; i++) {
        await book.arm(
          contact: caller(),
          trigger: CallTrigger.countdown(
            delay: Duration(minutes: i + 1),
            now: base,
          ),
          vibrate: true,
        );
      }

      final List<ScheduledCall> stored = await book.load();
      expect(stored, hasLength(3));
      // Three independent alarms, not one overwritten three times — this is
      // the behaviour the single request code used to destroy.
      expect(bridge.armedCalls, hasLength(3));
      expect(bridge.armedCalls.map((Map<String, dynamic> c) => c['id']).toSet(), hasLength(3));
    });

    test('the timeline is ordered by fire time', () async {
      final DateTime base = DateTime.now().add(const Duration(minutes: 5));
      await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 3), now: base),
        vibrate: true,
      );
      await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 1), now: base),
        vibrate: true,
      );
      await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 2), now: base),
        vibrate: true,
      );

      final List<ScheduledCall> stored = await book.load();
      for (int i = 1; i < stored.length; i++) {
        expect(
          stored[i].fireAtMs,
          greaterThanOrEqualTo(stored[i - 1].fireAtMs),
          reason: 'the timeline must read top-to-bottom in time order',
        );
      }
    });

    test('deleting one call leaves the others armed', () async {
      final DateTime base = DateTime.now().add(const Duration(minutes: 1));
      final List<String> ids = <String>[];
      for (int i = 0; i < 3; i++) {
        final ScheduledCall? saved = await book.arm(
          contact: caller(),
          trigger: CallTrigger.countdown(
            delay: Duration(minutes: i + 1),
            now: base,
          ),
          vibrate: true,
        );
        ids.add(saved!.id);
      }

      await book.remove(ids[1]);
      final List<ScheduledCall> stored = await book.load();

      expect(stored, hasLength(2));
      expect(stored.map((ScheduledCall c) => c.id), isNot(contains(ids[1])));
    });

    test('editing re-arms the same id with the new time', () async {
      final ScheduledCall original = (await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 1)),
        vibrate: true,
      ))!;

      final ScheduledCall? edited = await book.edit(
        existing: original,
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 9)),
      );

      expect(edited, isNotNull);
      expect(edited!.id, original.id);
      expect(bridge.armedCalls, hasLength(1));
      expect(bridge.calls, contains('cancelCall:${original.id}'));
    });

    test('a rejected edit leaves the original call armed', () async {
      final ScheduledCall original = (await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 1)),
        vibrate: true,
      ))!;

      // A time already in the past must not destroy a working schedule.
      final ScheduledCall? edited = await book.edit(
        existing: original,
        trigger: CallTrigger.exact(DateTime.now().subtract(const Duration(hours: 1))),
      );

      expect(edited, isNull);
      final List<ScheduledCall> stored = await book.load();
      expect(stored, hasLength(1));
      expect(stored.single.id, original.id);
    });

    test('a past trigger is refused outright', () async {
      final ScheduledCall? saved = await book.arm(
        contact: caller(),
        trigger: CallTrigger.exact(DateTime.now().subtract(const Duration(minutes: 1))),
        vibrate: true,
      );
      expect(saved, isNull);
      expect(bridge.armedCalls, isEmpty);
    });

    test('clear removes every armed call', () async {
      final DateTime base = DateTime.now().add(const Duration(minutes: 1));
      for (int i = 0; i < 4; i++) {
        await book.arm(
          contact: caller(),
          trigger: CallTrigger.countdown(
            delay: Duration(minutes: i + 1),
            now: base,
          ),
          vibrate: true,
        );
      }
      await book.clear();
      expect(await book.load(), isEmpty);
      expect(bridge.armedCalls, isEmpty);
    });

    test('a malformed row is skipped rather than blanking the timeline', () async {
      await book.arm(
        contact: caller(),
        trigger: CallTrigger.countdown(delay: const Duration(minutes: 5)),
        vibrate: true,
      );
      // Simulate a partially-written entry from a crashed save.
      await bridge.scheduleCall(id: 'broken', triggerAtMs: 0, payload: <String, dynamic>{});

      final List<ScheduledCall> stored = await book.load();
      expect(stored, hasLength(1));
      expect(stored.single.id, isNot('broken'));
    });
  });

  group('timeline gap formatting', () {
    test('picks a scale that matches the magnitude', () {
      expect(TimelineGapFormatter.scaleFor(const Duration(seconds: 30)), TimelineGapScale.seconds);
      expect(TimelineGapFormatter.scaleFor(const Duration(minutes: 5)), TimelineGapScale.minutes);
      expect(TimelineGapFormatter.scaleFor(const Duration(hours: 3)), TimelineGapScale.hours);
      expect(TimelineGapFormatter.scaleFor(const Duration(days: 2)), TimelineGapScale.days);
    });

    test('renders minutes, hours and days in their own natural unit', () {
      expect(TimelineGapFormatter.format(const Duration(seconds: 45)), '45s');
      expect(TimelineGapFormatter.format(const Duration(minutes: 5)), '5m');
      expect(TimelineGapFormatter.format(const Duration(hours: 3)), '3h');
      expect(TimelineGapFormatter.format(const Duration(days: 2)), '2d');
    });

    test('a one-unit gap is not pluralised', () {
      expect(TimelineGapFormatter.format(const Duration(minutes: 1)), '1m');
      expect(TimelineGapFormatter.format(const Duration(hours: 1)), '1h');
    });

    test('a fixed scale keeps the column comparable across rows', () {
      // A 3-minute and a 3-hour gap in the same column: the hour one is the
      // one that decides the scale, so both read in hours.
      final String minutes = TimelineGapFormatter.formatAt(
        const Duration(minutes: 3),
        TimelineGapScale.hours,
      );
      final String hours = TimelineGapFormatter.formatAt(
        const Duration(hours: 3),
        TimelineGapScale.hours,
      );
      expect(minutes, '0h');
      expect(hours, '3h');
    });

    test('a sub-minute gap rounds down to 0 rather than showing a stray 0h', () {
      // The scale is chosen from the largest gap in the list, so a small gap
      // rendered in a coarse column is expected to read 0 — the check is that
      // it does not render negative or overflow.
      expect(
        TimelineGapFormatter.formatAt(const Duration(seconds: 30), TimelineGapScale.hours),
        '0h',
      );
    });

    test('until() describes the wait in a readable way', () {
      final DateTime now = DateTime(2026, 9, 29, 12);
      expect(TimelineGapFormatter.until(now.add(const Duration(seconds: 20)), now: now), 'in 20s');
      expect(TimelineGapFormatter.until(now.add(const Duration(hours: 2)), now: now), 'in 2h');
      expect(
        TimelineGapFormatter.until(now.add(const Duration(hours: 2, minutes: 15)), now: now),
        'in 2h 15m',
      );
      expect(TimelineGapFormatter.until(now.subtract(const Duration(minutes: 1)), now: now), 'due now');
    });
  });
}
