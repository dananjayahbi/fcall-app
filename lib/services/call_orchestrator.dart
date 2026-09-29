import 'dart:async';

import '../core/models/call_session.dart';
import '../core/models/call_trigger.dart';
import '../core/models/caller_profile.dart';
import '../core/utils/logger.dart';
import '../data/repositories/caller_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'call_log/native_call_log_service.dart';
import 'platform/bridge_service.dart';
import 'platform/platform_bridge.dart';
import 'proximity/proximity_service.dart';
import 'ringer/ringer_service.dart';
import 'scheduling/schedule_service.dart';

/// The call lifecycle, expressed once and shared by every screen.
///
/// Both the config screen and the call screens talk to this object, so the
/// spec §4 state machine has exactly one implementation. `CallSession` is the
/// state; this class is the only thing allowed to move it.
class CallOrchestrator {
  CallOrchestrator({
    required CallerRepository callerRepository,
    required SettingsRepository settingsRepository,
    required NativeCallLogService callLogService,
    PlatformBridge? bridge,
  }) : _callerRepository = callerRepository,
       _settingsRepository = settingsRepository,
       _callLogService = callLogService,
       _bridge = bridge ?? BridgeService.instance.bridge {
    _ringer = RingerService(bridge: _bridge);
    _proximity = ProximityService(bridge: _bridge);
    _schedule = ScheduleService(bridge: _bridge);
  }

  final CallerRepository _callerRepository;
  final SettingsRepository _settingsRepository;
  final NativeCallLogService _callLogService;
  final PlatformBridge _bridge;

  late final RingerService _ringer;
  late final ProximityService _proximity;
  late final ScheduleService _schedule;

  final StreamController<CallSession> _sessionController =
      StreamController<CallSession>.broadcast();

  CallSession? _session;
  CallTrigger? _armedTrigger;
  AppSettings _settings = const AppSettings();
  int _sessionCounter = 0;

  Stream<CallSession> get sessionStream => _sessionController.stream;
  CallSession? get session => _session;
  CallTrigger? get armedTrigger => _armedTrigger;
  AppSettings get settings => _settings;
  bool get isArmed => _armedTrigger != null;
  bool get isInCall => _session != null && _session!.phase != CallPhase.ended;

  RingerService get ringer => _ringer;
  ProximityService get proximity => _proximity;
  ScheduleService get schedule => _schedule;
  NativeCallLogService get callLog => _callLogService;

  void _emit(CallSession next) {
    _session = next;
    if (!_sessionController.isClosed) _sessionController.add(next);
  }

  // ------------------------------------------------------------------ config
  Future<void> loadPersisted() async {
    _settings = await _settingsRepository.load();
    AppLogger.instance.info('orchestrator', 'settings loaded: $_settings');
  }

  Future<void> persistProfile(CallerProfile profile) =>
      _callerRepository.save(profile);

  Future<void> persistSettings(AppSettings settings) async {
    _settings = settings;
    await _settingsRepository.save(settings);
  }

  // -------------------------------------------------------------- scheduling
  /// Module 2: arm the platform alarm for [trigger].
  Future<ScheduleResult> arm({
    required CallerProfile profile,
    required CallTrigger trigger,
  }) async {
    if (isInCall) {
      return const ScheduleResult.failure('A call is already in progress.');
    }
    await persistProfile(profile);
    final ScheduleResult result = await _schedule.schedule(
      trigger: trigger,
      payload: _payloadFor(profile),
    );
    if (result.ok) {
      _armedTrigger = trigger;
    } else {
      _armedTrigger = null;
    }
    return result;
  }

  /// Module 2's fallback quick trigger: a 10 second countdown using the stored
  /// profile, no typing required.
  Future<ScheduleResult> armQuickAction({CallerProfile? profile}) async {
    final CallerProfile resolved = profile ?? await _callerRepository.load();
    return arm(profile: resolved, trigger: CallTrigger.quickAction());
  }

  Future<void> disarm() async {
    await _schedule.cancel();
    _armedTrigger = null;
  }

  Map<String, dynamic> _payloadFor(CallerProfile profile) {
    return <String, dynamic>{
      CallPayloadKeys.sessionId: _nextSessionId(),
      CallPayloadKeys.name: profile.displayName,
      CallPayloadKeys.number: profile.number,
      CallPayloadKeys.simLabel: profile.simLabel,
      CallPayloadKeys.vibrate: _settings.vibrate,
    };
  }

  String _nextSessionId() {
    _sessionCounter++;
    return '${DateTime.now().millisecondsSinceEpoch}-$_sessionCounter';
  }

  // --------------------------------------------------------------- ringing
  /// Module 2/3: the alarm fired (or the in-app timer fired). Bring the call up.
  Future<void> beginRinging({
    required String name,
    required String number,
    String simLabel = 'SIM 1',
  }) async {
    if (isInCall) return;
    final CallSession created = CallSession.start(
      id: _nextSessionId(),
      profileName: name,
      profileNumber: number,
      simLabel: simLabel,
      startedAt: DateTime.now(),
    );
    _emit(created.copyWith(phase: CallPhase.ringing));

    // Module 3 — window flags for the lock-screen takeover.
    await _bridge.setLockScreenTakeover(enabled: true);
    await _bridge.setKeepScreenOn(enabled: _settings.screenOnWhileRinging);
    await _bridge.setVoiceCommunicationMode(enabled: true);

    // Module 4 — ringtone + looped vibration.
    await _ringer.start(vibrate: _settings.vibrate);
    AppLogger.instance.info('orchestrator', 'ringing: $name <$number>');
  }

  /// Module 4: a physical volume key muted the ringer; the screen stays up.
  Future<void> onVolumeKeyPressed() async {
    if (_session?.phase != CallPhase.ringing) return;
    await _ringer.silenceForVolumeKey();
    final CallSession? current = _session;
    if (current != null) {
      _emit(current.copyWith(ringerSilenced: true));
    }
  }

  // ---------------------------------------------------------------- active
  /// Module 5: answer. Ringtone stops with no tail, timer starts, proximity
  /// engages so the screen blacks out at the ear.
  Future<void> answer() async {
    final CallSession? current = _session;
    if (current == null || current.phase != CallPhase.ringing) return;

    await _ringer.stop();
    _emit(current.copyWith(phase: CallPhase.active, answeredAt: DateTime.now()));
    await _proximity.start();
    AppLogger.instance.info('orchestrator', 'answered');
  }

  // ------------------------------------------------------------ termination
  /// Module 5/6: end the call, record it, release every hardware resource, and
  /// restore the device to its previous state.
  Future<CallLogWriteResult?> end({
    CallResolution resolution = CallResolution.answered,
    String reason = '',
  }) async {
    final CallSession? current = _session;
    if (current == null || current.phase == CallPhase.ended) return null;

    await _ringer.stop();
    await _proximity.stop();

    final CallSession ended = current.copyWith(
      phase: CallPhase.ended,
      resolution: resolution,
      endedAt: DateTime.now(),
      endedReason: reason,
    );
    _emit(ended);

    // Module 3/5 — release locks, clear overlay flags, return to the launcher.
    await _bridge.setKeepScreenOn(enabled: false);
    await _bridge.setVoiceCommunicationMode(enabled: false);
    await _bridge.setLockScreenTakeover(enabled: false);
    await _bridge.hideOverlay();

    CallLogWriteResult? result;
    if (_settings.logCalls) {
      result = await _callLogService.record(ended);
    }
    AppLogger.instance.info('orchestrator', 'ended (${resolution.name})');
    return result;
  }

  /// Convenience wrappers so callers read naturally.
  Future<CallLogWriteResult?> decline() =>
      end(resolution: CallResolution.declined, reason: 'Declined');

  Future<CallLogWriteResult?> miss() =>
      end(resolution: CallResolution.missed, reason: 'No answer');

  Future<CallLogWriteResult?> hangUp() =>
      end(resolution: CallResolution.answered, reason: 'Ended');

  Future<void> dispose() async {
    await _ringer.dispose();
    await _proximity.dispose();
    await _sessionController.close();
  }
}
