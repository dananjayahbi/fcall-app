import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/call_orchestrator.dart';

/// Which in-call control is toggled on. Purely visual — none of these produce
/// audio, which is the point of the exercise.
enum CallControl { mute, keypad, speaker, addCall }

/// Module 5 state that belongs to the screen rather than to the session:
/// the running timer, the proximity state, and the toggled control buttons.
class ActiveCallController extends ChangeNotifier {
  ActiveCallController({
    required CallOrchestrator orchestrator,
    required DateTime answeredAt,
  }) : _answeredAt = answeredAt {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds = DateTime.now().difference(_answeredAt).inSeconds;
      notifyListeners();
    });
    _elapsedSeconds = DateTime.now().difference(_answeredAt).inSeconds;
    _proximitySub = orchestrator.proximity.nearStream.listen((bool near) {
      _isNear = near;
      notifyListeners();
    });
  }

  final DateTime _answeredAt;

  late final Timer _timer;
  StreamSubscription<bool>? _proximitySub;

  int _elapsedSeconds = 0;
  bool _isNear = false;
  final Set<CallControl> _active = <CallControl>{};

  int get elapsedSeconds => _elapsedSeconds;
  bool get isNear => _isNear;
  Set<CallControl> get activeControls => Set<CallControl>.unmodifiable(_active);

  bool isActive(CallControl control) => _active.contains(control);

  void toggle(CallControl control) {
    if (!_active.remove(control)) _active.add(control);
    notifyListeners();
  }

  /// Clears every visual control state. Called on teardown so a re-answered
  /// call never inherits Mute/Speaker from the previous one.
  void resetControls() {
    _active.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    _proximitySub?.cancel();
    super.dispose();
  }
}
