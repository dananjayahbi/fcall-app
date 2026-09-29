/// How the user asked for the call to be delivered.
enum CallTriggerKind {
  /// A relative delay counted down from the moment of scheduling.
  countdown,

  /// A wall-clock date + time picked by the user.
  exactDateTime,

  /// Fired by a launcher shortcut / quick-settings tile. Always ~10s.
  quickAction,
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
  };

  factory CallTrigger.fromJson(Map<String, dynamic> json) {
    return CallTrigger._(
      kind: CallTriggerKind.values.firstWhere(
        (CallTriggerKind k) => k.name == json['kind'],
        orElse: () => CallTriggerKind.countdown,
      ),
      fireAtMs: (json['fireAtMs'] as num).toInt(),
      presetLabel: json['presetLabel'] as String?,
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
}

class CallTriggerOption {
  const CallTriggerOption(this.label, this.duration);

  final String label;
  final Duration duration;
}
