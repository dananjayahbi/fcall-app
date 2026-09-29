import 'call_trigger.dart';

/// One armed call waiting to fire.
///
/// ## Why this is not just a [CallTrigger]
///
/// A trigger is a *rule* ("15 minutes from now"). A schedule is a **booked,
/// addressable instance** of one: it has an id the user can edit or delete, it
/// must survive a reboot and a process death, and several of them coexist with
/// independent alarm registrations behind them.
///
/// [CallTrigger] is deliberately not embedded, because editing a schedule
/// re-derives a new trigger from the edited values rather than mutating the
/// existing one — the fire time is stored absolutely so it cannot drift.
class ScheduledCall {
  const ScheduledCall({
    required this.id,
    required this.trigger,
    required this.contactId,
    required this.contactName,
    required this.contactNumber,
    this.simLabel = 'SIM 1',
    this.vibrate = true,
    this.randomised = false,
  });

  /// Native id. Kept as a String so the Dart/Kotlin boundary never has to agree
  /// on an integer width.
  final String id;
  final CallTrigger trigger;

  /// Empty for a manually-typed number, non-empty when picked from the book.
  final String contactId;
  final String contactName;
  final String contactNumber;
  final String simLabel;
  final bool vibrate;

  /// True when this row was filled in by the random picker, so the timeline can
  /// label it honestly instead of implying the user chose that contact.
  final bool randomised;

  DateTime get fireAt => trigger.fireAt;
  int get fireAtMs => trigger.fireAtMs;

  String get displayName =>
      contactName.trim().isNotEmpty ? contactName.trim() : contactNumber;

  bool isPast({DateTime? now}) => trigger.isInPast(now: now);
  Duration timeRemaining({DateTime? now}) => trigger.timeRemaining(now: now);

  ScheduledCall copyWith({
    CallTrigger? trigger,
    String? contactId,
    String? contactName,
    String? contactNumber,
    String? simLabel,
    bool? vibrate,
    bool? randomised,
  }) {
    return ScheduledCall(
      id: id,
      trigger: trigger ?? this.trigger,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactNumber: contactNumber ?? this.contactNumber,
      simLabel: simLabel ?? this.simLabel,
      vibrate: vibrate ?? this.vibrate,
      randomised: randomised ?? this.randomised,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'trigger': trigger.toJson(),
    'contactId': contactId,
    'contactName': contactName,
    'contactNumber': contactNumber,
    'simLabel': simLabel,
    'vibrate': vibrate,
    'randomised': randomised,
  };

  factory ScheduledCall.fromJson(Map<String, dynamic> json) {
    final Object? rawTrigger = json['trigger'];
    return ScheduledCall(
      id: (json['id'] as String?) ?? '',
      trigger: rawTrigger is Map<String, dynamic>
          ? CallTrigger.fromJson(rawTrigger)
          : CallTrigger.countdown(delay: Duration.zero),
      contactId: (json['contactId'] as String?) ?? '',
      contactName: (json['contactName'] as String?) ?? '',
      contactNumber: (json['contactNumber'] as String?) ?? '',
      simLabel: (json['simLabel'] as String?) ?? 'SIM 1',
      vibrate: (json['vibrate'] as bool?) ?? true,
      randomised: (json['randomised'] as bool?) ?? false,
    );
  }
}
