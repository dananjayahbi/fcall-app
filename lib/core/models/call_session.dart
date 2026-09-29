/// Lifecycle of one call — the spec §4 state machine, in code.
enum CallPhase {
  /// Configured but not yet scheduled.
  idle,

  /// Registered with the platform, waiting for the fire time.
  scheduled,

  /// Alarm fired; ringing, nobody has picked up yet.
  ringing,

  /// Answered: timer running, total silence, proximity live.
  active,

  /// Ended. The terminal state.
  ended,
}

/// What the user did with the ringing call.
enum CallResolution {
  answered,
  declined,
  missed,
}

/// Module 4/5 aggregate: the single object the call screens read from.
///
/// This is the Dart-side source of truth. On Android the identical payload is
/// mirrored into SharedPreferences (`CallSessionStore`) so a cold start
/// launched by a `BroadcastReceiver` — with no Dart VM running — can rebuild the
/// identical screen.
class CallSession {
  const CallSession({
    required this.id,
    required this.profileName,
    required this.profileNumber,
    required this.simLabel,
    required this.startedAt,
    this.phase = CallPhase.idle,
    this.resolution,
    this.answeredAt,
    this.endedAt,
    this.ringerSilenced = false,
    this.endedReason = '',
  });

  factory CallSession.start({
    required String id,
    required String profileName,
    required String profileNumber,
    required String simLabel,
    required DateTime startedAt,
  }) {
    return CallSession(
      id: id,
      profileName: profileName,
      profileNumber: profileNumber,
      simLabel: simLabel,
      startedAt: startedAt,
    );
  }

  final String id;
  final String profileName;
  final String profileNumber;
  final String simLabel;
  final DateTime startedAt;

  final CallPhase phase;
  final CallResolution? resolution;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  /// True once a volume key muted the ringer (Module 4 contract).
  final bool ringerSilenced;

  /// Human-readable termination note shown on the call-log row.
  final String endedReason;

  String get displayName =>
      profileName.trim().isNotEmpty ? profileName.trim() : profileNumber;

  /// Seconds on the in-call timer. Ticks from the moment of answer.
  int get answeredDurationSeconds {
    if (answeredAt == null) {
      return 0;
    }
    final DateTime end = endedAt ?? DateTime.now();
    return end.difference(answeredAt!).inSeconds;
  }

  /// For a missed call there is no answer, so the ring duration is reported.
  int get ringDurationSeconds => (endedAt ?? DateTime.now())
      .difference(startedAt)
      .inSeconds;

  CallSession copyWith({
    CallPhase? phase,
    CallResolution? resolution,
    DateTime? answeredAt,
    DateTime? endedAt,
    bool? ringerSilenced,
    String? endedReason,
  }) {
    return CallSession(
      id: id,
      profileName: profileName,
      profileNumber: profileNumber,
      simLabel: simLabel,
      startedAt: startedAt,
      phase: phase ?? this.phase,
      resolution: resolution ?? this.resolution,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      ringerSilenced: ringerSilenced ?? this.ringerSilenced,
      endedReason: endedReason ?? this.endedReason,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'profileName': profileName,
    'profileNumber': profileNumber,
    'simLabel': simLabel,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'phase': phase.name,
    'resolution': resolution?.name,
    'answeredAt': answeredAt?.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'ringerSilenced': ringerSilenced,
    'endedReason': endedReason,
  };

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: (json['id'] as String?) ?? '',
      profileName: (json['profileName'] as String?) ?? '',
      profileNumber: (json['profileNumber'] as String?) ?? '',
      simLabel: (json['simLabel'] as String?) ?? 'SIM 1',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['startedAt'] as num?)?.toInt() ?? 0,
      ),
      phase: CallPhase.values.firstWhere(
        (CallPhase p) => p.name == json['phase'],
        orElse: () => CallPhase.idle,
      ),
      resolution: json['resolution'] == null
          ? null
          : CallResolution.values.firstWhere(
              (CallResolution r) => r.name == json['resolution'],
              orElse: () => CallResolution.missed,
            ),
      answeredAt: _dateOrNull(json['answeredAt']),
      endedAt: _dateOrNull(json['endedAt']),
      ringerSilenced: (json['ringerSilenced'] as bool?) ?? false,
      endedReason: (json['endedReason'] as String?) ?? '',
    );
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((value as num).toInt());
  }
}
