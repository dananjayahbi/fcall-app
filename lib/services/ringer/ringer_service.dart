import 'dart:async';

import '../../core/utils/logger.dart';
import '../platform/bridge_service.dart';
import '../platform/platform_bridge.dart';

/// Module 4 audio + haptics, expressed as state so the UI can render the ringer
/// indicator without duplicating the truth.
class RingerState {
  const RingerState({
    this.active = false,
    this.silenced = false,
    this.vibrating = false,
  });

  final bool active;
  final bool silenced;
  final bool vibrating;

  RingerState copyWith({bool? active, bool? silenced, bool? vibrating}) {
    return RingerState(
      active: active ?? this.active,
      silenced: silenced ?? this.silenced,
      vibrating: vibrating ?? this.vibrating,
    );
  }
}

/// Module 4: owns ringtone playback, the vibration pattern, and the volume-key
/// mute policy.
///
/// The important behaviour here is the *one-shot* nature of a volume-key mute:
/// on a real handset, one press silences the ring, and the call screen stays up.
/// It is not a toggle — a second press must not resume the ringtone.
class RingerService {
  RingerService({PlatformBridge? bridge})
    : _bridge = bridge ?? BridgeService.instance.bridge;

  final PlatformBridge _bridge;

  final StreamController<RingerState> _stateController =
      StreamController<RingerState>.broadcast();

  RingerState _state = const RingerState();
  RingerState get state => _state;
  Stream<RingerState> get stateStream => _stateController.stream;

  void _emit(RingerState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  /// Begin ringing. Ringtone via the system default + the looped call pattern.
  Future<void> start({required bool vibrate}) async {
    await _bridge.startRinger(vibrate: vibrate);
    _emit(RingerState(active: true, silenced: false, vibrating: vibrate));
    AppLogger.instance.info('ringer', 'started (vibrate=$vibrate)');
  }

  /// Stop with no audio tail (Module 5: "terminate instantly").
  Future<void> stop() async {
    await _bridge.stopRinger();
    _emit(const RingerState());
    AppLogger.instance.info('ringer', 'stopped');
  }

  /// Physical volume key pressed while ringing: mute, keep the screen up.
  ///
  /// Idempotent by design — a second press must not restart the ringtone.
  Future<void> silenceForVolumeKey() async {
    if (_state.silenced) {
      AppLogger.instance.info('ringer', 'volume key ignored (already silent)');
      return;
    }
    await _bridge.silenceRinger();
    _emit(RingerState(active: false, silenced: true, vibrating: false));
    AppLogger.instance.info('ringer', 'silenced by volume key');
  }

  /// Config-screen ringtone preview.
  Future<void> preview() => _bridge.previewRinger();

  Future<void> dispose() async {
    await _stateController.close();
  }
}
