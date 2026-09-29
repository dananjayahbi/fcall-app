import 'dart:collection';

/// Tiny in-memory ring buffer exposed on the Setup page.
///
/// Purpose: when a call does not appear, the question is always "what did the
/// bridge actually do?". Logging to the console alone loses that the moment the
/// screen is dismissed, and on web the console is not easily reachable while the
/// call overlay is up.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _capacity = 200;

  final Queue<String> _entries = Queue<String>();
  final List<void Function(String)> _sinks = <void Function(String)>[];

  /// Most recent first.
  List<String> get entries => _entries.toList(growable: false).reversed.toList();

  void addSink(void Function(String) sink) => _sinks.add(sink);

  void log(String scope, String message) {
    final String line =
        '${DateTime.now().toIso8601String().substring(11, 19)} [$scope] $message';
    _entries.addLast(line);
    while (_entries.length > _capacity) {
      _entries.removeFirst();
    }
    for (final void Function(String) sink in _sinks) {
      sink(line);
    }
    debugPrint(line);
  }

  void info(String scope, String message) => log(scope, message);

  void warn(String scope, String message) => log(scope, 'WARN  $message');

  void error(String scope, String message) => log(scope, 'ERROR $message');

  void clear() => _entries.clear();
}

/// `debugPrint` exists in Flutter; re-export so `logger.dart` is self-contained.
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
