import 'dart:async';

import '../../core/models/call_trigger.dart';
import '../../core/models/contact.dart';
import '../../core/models/scheduled_call.dart';
import '../../core/utils/logger.dart';
import '../platform/bridge_service.dart';
import '../platform/platform_bridge.dart';

/// Owns the set of armed calls.
///
/// ## Why a service and not a widget
///
/// The armed set is *shared state* with three independent writers — the home
/// screen arms, the timeline edits and deletes, and an alarm firing removes a
/// row natively. Putting that in a widget would mean the timeline could show a
/// call the platform has already delivered. This is the single place that
/// reconciles Dart's view with the platform's.
class ScheduleBook {
  ScheduleBook({PlatformBridge? bridge})
    : _bridge = bridge ?? BridgeService.instance.bridge;

  final PlatformBridge _bridge;

  final StreamController<List<ScheduledCall>> _changes =
      StreamController<List<ScheduledCall>>.broadcast();

  Stream<List<ScheduledCall>> get changes => _changes.stream;

  int _counter = 0;

  /// Mints a schedule id.
  ///
  /// Microsecond time plus a counter, so two schedules armed inside the same
  /// millisecond cannot collide. A bare timestamp would, and a collision means
  /// one silently overwrites the other.
  String newId() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  /// Arms one call and returns the stored row.
  ///
  /// Returns `null` when the trigger is already in the past — such a schedule
  /// would fire the instant it is registered, which reads as a broken button.
  Future<ScheduledCall?> arm({
    required Contact contact,
    required CallTrigger trigger,
    required bool vibrate,
    bool randomised = false,
    String? id,
  }) async {
    if (!trigger.isValid()) {
      AppLogger.instance.warn('schedule-book', 'refused a past trigger');
      return null;
    }
    final String scheduleId = id ?? newId();
    await _bridge.scheduleCall(
      id: scheduleId,
      triggerAtMs: trigger.fireAtMs,
      payload: <String, dynamic>{
        'name': contact.name,
        'number': contact.number,
        'simLabel': contact.simLabel,
        'vibrate': vibrate,
        'contactId': contact.id,
        'randomised': randomised,
      },
    );
    final ScheduledCall saved = ScheduledCall(
      id: scheduleId,
      trigger: trigger,
      contactId: contact.id,
      contactName: contact.name,
      contactNumber: contact.number,
      simLabel: contact.simLabel,
      vibrate: vibrate,
      randomised: randomised,
    );
    _emitChange();
    return saved;
  }

  /// Re-arms an existing row with a new trigger.
  ///
  /// Cancels first, then re-registers. If the new trigger is invalid the
  /// original is left armed — a rejected edit must not destroy the call the
  /// user was trying to change.
  Future<ScheduledCall?> edit({
    required ScheduledCall existing,
    required CallTrigger trigger,
  }) async {
    if (!trigger.isValid()) return null;
    await _bridge.cancelCall(id: existing.id);
    return arm(
      contact: Contact(
        id: existing.contactId,
        name: existing.contactName,
        number: existing.contactNumber,
        simLabel: existing.simLabel,
      ),
      trigger: trigger,
      vibrate: existing.vibrate,
      randomised: existing.randomised,
      id: existing.id,
    );
  }

  Future<void> remove(String id) async {
    await _bridge.cancelCall(id: id);
    _emitChange();
  }

  Future<void> clear() async {
    await _bridge.clearScheduledCalls();
    _emitChange();
  }

  /// Reads the armed set from the platform, newest fire time last.
  ///
  /// Sorted ascending so the timeline reads top-to-bottom in time order, and
  /// past entries are dropped: a delivered call is removed natively, but if a
  /// device was off when one elapsed, the row is still stored and showing it
  /// as a live schedule would be wrong.
  Future<List<ScheduledCall>> load({bool includePast = false}) async {
    final List<Map<String, dynamic>> raw = await _bridge.listScheduledCalls();
    final DateTime now = DateTime.now();
    final List<ScheduledCall> parsed = <ScheduledCall>[];
    for (final Map<String, dynamic> entry in raw) {
      final ScheduledCall? call = _fromPlatform(entry);
      if (call == null) continue;
      if (!includePast && call.isPast(now: now)) continue;
      parsed.add(call);
    }
    parsed.sort(
      (ScheduledCall a, ScheduledCall b) => a.fireAtMs.compareTo(b.fireAtMs),
    );
    return parsed;
  }

  /// Rebuilds a row from the platform's flat map.
  ///
  /// Returns `null` for an entry without a usable id or fire time rather than
  /// throwing — one malformed row must not blank the entire timeline.
  ScheduledCall? _fromPlatform(Map<String, dynamic> entry) {
    final String id = (entry['id'] as String?) ?? '';
    final Object? fireAt = entry['fireAtMs'] ?? entry['fireAt'];
    if (id.isEmpty || fireAt is! num) return null;
    final int fireAtMs = fireAt.toInt();
    return ScheduledCall(
      id: id,
      trigger: CallTrigger.exact(
        DateTime.fromMillisecondsSinceEpoch(fireAtMs),
      ),
      contactId: (entry['contactId'] as String?) ?? '',
      contactName: (entry['name'] as String?) ?? '',
      contactNumber: (entry['number'] as String?) ?? '',
      simLabel: (entry['simLabel'] as String?) ?? 'SIM 1',
      vibrate: (entry['vibrate'] as bool?) ?? true,
      randomised: (entry['randomised'] as bool?) ?? false,
    );
  }

  void _emitChange() {
    if (_changes.isClosed) return;
    unawaited(
      load().then((List<ScheduledCall> next) {
        if (!_changes.isClosed) _changes.add(next);
      }),
    );
  }

  Future<void> dispose() => _changes.close();
}
