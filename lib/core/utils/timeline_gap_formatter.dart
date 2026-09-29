import 'time_formatter.dart';

/// Human wording for the gap *between* two scheduled calls.
///
/// The timeline's whole point is legibility at a glance, and "14:32" twice in
/// a row says nothing about whether those calls are 2 minutes or 2 days apart.
/// The scale is chosen so the label stays short at the top of the range and
/// gains detail as the gap grows, rather than one format trying to cover all
/// four scales.
enum TimelineGapScale {
  seconds,
  minutes,
  hours,
  days;

  /// The next scale up, or `null` at the top.
  TimelineGapScale? get next => switch (this) {
    TimelineGapScale.seconds => TimelineGapScale.minutes,
    TimelineGapScale.minutes => TimelineGapScale.hours,
    TimelineGapScale.hours => TimelineGapScale.days,
    TimelineGapScale.days => null,
  };
}

/// Formats inter-call gaps for the schedule timeline.
abstract final class TimelineGapFormatter {
  static const int _minutesFloor = 60;
  static const int _hoursFloor = 60 * 60;
  static const int _daysFloor = 24 * 60 * 60;

  /// Picks the scale a duration is best described in.
  static TimelineGapScale scaleFor(Duration gap) {
    final int seconds = gap.inSeconds.abs();
    if (seconds < _minutesFloor) return TimelineGapScale.seconds;
    if (seconds < _hoursFloor) return TimelineGapScale.minutes;
    if (seconds < _daysFloor) return TimelineGapScale.hours;
    return TimelineGapScale.days;
  }

  /// Renders [gap] in the scale appropriate to its own magnitude.
  static String format(Duration gap) {
    if (gap.inSeconds < 0) return 'now';
    return switch (scaleFor(gap)) {
      TimelineGapScale.seconds => '${gap.inSeconds}s',
      TimelineGapScale.minutes => _plural(gap.inMinutes, 'm'),
      TimelineGapScale.hours => _plural(gap.inHours, 'h'),
      TimelineGapScale.days => _plural(gap.inDays, 'd'),
    };
  }

  /// Renders the gap in a *fixed* scale, so a stack of rows lines up and the eye
  /// can compare magnitudes without re-reading the unit each time.
  ///
  /// Used for the timeline's left-hand gap column.
  static String formatAt(Duration gap, TimelineGapScale scale) {
    return switch (scale) {
      TimelineGapScale.seconds => '${gap.inSeconds}s',
      TimelineGapScale.minutes => _plural(gap.inMinutes, 'm'),
      TimelineGapScale.hours => _plural(gap.inHours, 'h'),
      TimelineGapScale.days => _plural(gap.inDays, 'd'),
    };
  }

  /// The coarser of two scales — the right choice for a column of mixed gaps,
  /// so a 3-hour and a 3-minute gap are not rendered in the same column at
  /// different precisions and read as a mismatch.
  static TimelineGapScale coarser(TimelineGapScale a, TimelineGapScale b) =>
      a.index <= b.index ? b : a;

  /// Longer form for the detail row: "in 2 h 15 min".
  static String until(DateTime fireAt, {DateTime? now}) {
    final Duration remaining = fireAt.difference(now ?? DateTime.now());
    if (remaining.isNegative) return 'due now';
    if (remaining.inSeconds < 60) return 'in ${remaining.inSeconds}s';    final int hours = remaining.inHours;
    final int minutes = remaining.inMinutes.remainder(60);
    if (hours == 0) return 'in ${TimeFormatter.countdown(remaining)}';
    if (minutes == 0) return 'in $hours' 'h';
    return 'in $hours' 'h $minutes' 'm';
  }

  static String _plural(int value, String unit) =>
      value == 1 ? '1$unit' : '$value$unit';
}
