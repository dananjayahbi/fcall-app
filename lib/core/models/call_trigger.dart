/// How the user asked for the call to be delivered.
enum CallTriggerKind {
  /// A relative delay counted down from the moment of scheduling.
  countdown,

  /// A relative delay the user typed in units (e.g. "2 hours"), built by
  /// [CallTrigger.relative].
  ///
  /// Kept distinct from [countdown] so the timeline can label a hand-typed
  /// delay differently from a preset, and so the unit the user chose survives
  /// to be shown. It is *not* just a countdown with a different label: the
  /// pairing (unit, value) is what the user entered, and re-rendering it in
  /// seconds would lose that.
  relative,

  /// A wall-clock date + time picked by the user.
  exactDateTime,

  /// Fired by a launcher shortcut / quick-settings tile. Always ~10s.
  quickAction,
}

/// The unit a [CallTriggerKind.relative] delay was entered in.
enum RelativeUnit {
  minutes,
  hours;

  String get label => this == RelativeUnit.minutes ? 'Minutes' : 'Hours';
  String get shortLabel => this == RelativeUnit.minutes ? 'min' : 'hr';

  Duration toDuration(int value) => this == RelativeUnit.minutes
      ? Duration(minutes: value)
      : Duration(hours: value);
}


/// Module 1 trigger configuration.
///
/// Deliberately holds the *absolute* fire time as well as the relative duration:
/// the native layer needs an epoch millisecond value (it cannot read a "5 minutes"
/// after the process is killed), and a countdown that is re-read at fire time
/// would drift.
class CallTrigger {
  const CallTrigger._({
    required this.kind,
    required this.fireAtMs,
    this.presetLabel,
    this.relativeUnit,
    this.relativeValue,
  });

  /// Quick preset / custom relative delay.
  factory CallTrigger.countdown({
    required Duration delay,
    String? presetLabel,
    DateTime? now,
  }) {
    final DateTime base = now ?? DateTime.now();
    return CallTrigger._(
      kind: CallTriggerKind.countdown,
      fireAtMs: base.add(delay).millisecondsSinceEpoch,
      presetLabel: presetLabel,
    );
  }

  /// Exact wall-clock appointment.
  factory CallTrigger.exact(DateTime dateTime) => CallTrigger._(
    kind: CallTriggerKind.exactDateTime,
    fireAtMs: dateTime.millisecondsSinceEpoch,
  );

  /// A delay the user entered as (value, unit) — "2 hours", "45 minutes".
  ///
  /// [value] is clamped to at least 1: a zero delay would fire instantly, which
  /// is indistinguishable from a broken button, and a negative one is a schedule
  /// that can never fire. The clamp is silent rather than an error because the
  /// caller's job is to schedule the call, not to lecture about the input.
  factory CallTrigger.relative({
    required int value,
    required RelativeUnit unit,
    DateTime? now,
  }) {
    final int safe = value < 1 ? 1 : value;
    return CallTrigger._(
      kind: CallTriggerKind.relative,
      fireAtMs:
          (now ?? DateTime.now()).add(unit.toDuration(safe)).millisecondsSinceEpoch,
      relativeUnit: unit,
      relativeValue: safe,
    );
  }

  /// Module 2's fallback quick trigger: a 10 second countdown.
  factory CallTrigger.quickAction({DateTime? now}) => CallTrigger._(
    kind: CallTriggerKind.quickAction,
    fireAtMs:
        (now ?? DateTime.now()).add(const Duration(seconds: 10)).millisecondsSinceEpoch,
    presetLabel: 'Quick action',
  );

  final CallTriggerKind kind;
  final int fireAtMs;
  final String? presetLabel;

  /// Set only for [CallTriggerKind.relative], so the editor can restore the
  /// unit the user chose instead of defaulting back to minutes.
  final RelativeUnit? relativeUnit;
  final int? relativeValue;

  /// "2 hr" / "45 min" — used by the timeline to describe the delay the way
  /// the user entered it rather than as a raw seconds count.
  String? get relativeLabel {
    if (relativeUnit == null || relativeValue == null) return null;
    return '$relativeValue ${relativeUnit!.shortLabel}';
  }

  DateTime get fireAt => DateTime.fromMillisecondsSinceEpoch(fireAtMs);

  Duration timeRemaining({DateTime? now}) =>
      fireAt.difference(now ?? DateTime.now());

  bool isInPast({DateTime? now}) => timeRemaining(now: now).isNegative;

  /// Guard against a schedule that is already stale by the time it is registered
  /// (e.g. the user picked a time in the past on a slow device).
  bool isValid({DateTime? now}) => !isInPast(now: now);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'fireAtMs': fireAtMs,
    'presetLabel': presetLabel,
    'relativeUnit': relativeUnit?.name,
    'relativeValue': relativeValue,
  };

  factory CallTrigger.fromJson(Map<String, dynamic> json) {
    final String? unitName = json['relativeUnit'] as String?;
    return CallTrigger._(
      kind: CallTriggerKind.values.firstWhere(
        (CallTriggerKind k) => k.name == json['kind'],
        orElse: () => CallTriggerKind.countdown,
      ),
      fireAtMs: (json['fireAtMs'] as num).toInt(),
      presetLabel: json['presetLabel'] as String?,
      // Unknown unit names degrade to minutes rather than throwing: a payload
      // written by a newer build must not crash an older one.
      relativeUnit: RelativeUnit.values.firstWhere(
        (RelativeUnit u) => u.name == unitName,
        orElse: () => RelativeUnit.minutes,
      ),
      relativeValue: (json['relativeValue'] as num?)?.toInt(),
    );
  }
}

/// The delay presets offered on the config screen (Module 1 / Phase 4.1).
abstract final class CallTriggerPresets {
  static const List<CallTriggerOption> all = <CallTriggerOption>[
    CallTriggerOption('15s', Duration(seconds: 15)),
    CallTriggerOption('30s', Duration(seconds: 30)),
    CallTriggerOption('1m', Duration(minutes: 1)),
    CallTriggerOption('5m', Duration(minutes: 5)),
  ];

  /// Sensible starting values for the minute/hour editor.
  static const int defaultMinutes = 10;
  static const int defaultHours = 1;
}

class CallTriggerOption {
  const CallTriggerOption(this.label, this.duration);

  final String label;
  final Duration duration;
}
