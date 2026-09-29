import 'call_session.dart';

/// Module 6 / Phase 5.1: the exact row that gets written into Android's
/// `CallLog.Calls` content provider.
///
/// Column mapping is annotated so the native writer is a mechanical translation
/// and cannot drift from the model.
class SimCallLogEntry {
  const SimCallLogEntry({
    required this.sessionId,
    required this.number,
    required this.cachedName,
    required this.startedAt,
    required this.durationSeconds,
    required this.resolution,
  });

  factory SimCallLogEntry.fromSession(CallSession session) {
    final int duration = session.resolution == CallResolution.answered
        ? session.answeredDurationSeconds
        : 0;
    return SimCallLogEntry(
      sessionId: session.id,
      number: session.profileNumber,
      cachedName: session.displayName,
      startedAt: session.startedAt,
      durationSeconds: duration,
      resolution: session.resolution ?? CallResolution.missed,
    );
  }

  final String sessionId;
  final String number;
  final String cachedName;
  final DateTime startedAt;
  final int durationSeconds;
  final CallResolution resolution;

  /// `CallLog.Calls.TYPE` — INCOMING(1) for all three, since a declined or
  /// missed *incoming* call is still an incoming call in the native log.
  /// `CallLog.Calls` distinguishes outcome via `MISSED_REASON`/`DISCONNECTED_…`.
  int get callLogType => 1;

  /// `CallLog.Calls.MISSED_REASON` — 0 means "not a missed call by the system",
  /// 1 = missed, 2 = rejected. Only meaningful when [isMissed].
  int get missedReason {
    switch (resolution) {
      case CallResolution.answered:
        return 0;
      case CallResolution.missed:
        return 1;
      case CallResolution.declined:
        return 2;
    }
  }

  bool get isMissed =>
      resolution == CallResolution.missed || resolution == CallResolution.declined;

  String get displayType => switch (resolution) {
    CallResolution.answered => 'Incoming',
    CallResolution.missed => 'Missed',
    CallResolution.declined => 'Rejected',
  };

  String get durationLabel {
    if (resolution == CallResolution.answered) {
      final int m = durationSeconds ~/ 60;
      final int s = durationSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return 'No answer';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'number': number,
    'cachedName': cachedName,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'durationSeconds': durationSeconds,
    'resolution': resolution.name,
  };

  factory SimCallLogEntry.fromJson(Map<String, dynamic> json) {
    return SimCallLogEntry(
      sessionId: (json['sessionId'] as String?) ?? '',
      number: (json['number'] as String?) ?? '',
      cachedName: (json['cachedName'] as String?) ?? '',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['startedAt'] as num?)?.toInt() ?? 0,
      ),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      resolution: CallResolution.values.firstWhere(
        (CallResolution r) => r.name == json['resolution'],
        orElse: () => CallResolution.missed,
      ),
    );
  }
}
