/// Formatting helpers for the call timer and the countdown.
abstract final class TimeFormatter {
  /// `00:00` -> `01:07`, and past an hour `01:02:03`.
  static String callTimer(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final int hours = safe ~/ 3600;
    final int minutes = (safe % 3600) ~/ 60;
    final int secs = safe % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = secs.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// `4s`, `1m 05s`, `2h 10m` — used for "rings in …".
  static String countdown(Duration duration) {
    if (duration.isNegative) return 'now';
    final int totalSeconds = duration.inSeconds;
    if (totalSeconds < 60) return '${totalSeconds}s';
    if (totalSeconds < 3600) {
      final int m = totalSeconds ~/ 60;
      final int s = totalSeconds % 60;
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    final int h = totalSeconds ~/ 3600;
    final int m = (totalSeconds % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  /// Wall-clock time for the call-log list: `09:41`.
  static String clockTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// `Today`, `Yesterday`, or `12 Sep`.
  static String relativeDay(DateTime value, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final DateTime a = DateTime(value.year, value.month, value.day);
    final DateTime b = DateTime(reference.year, reference.month, reference.day);
    final int diff = b.difference(a).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  /// Long form for the exact-time picker: `Wed, 12 Sep • 21:30`.
  static String exactDateTime(DateTime value) {
    const List<String> weekdays = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '${weekdays[value.weekday - 1]}, ${value.day} '
        '${months[value.month - 1]} • $h:$m';
  }
}
