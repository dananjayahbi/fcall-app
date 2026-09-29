import 'dart:async';

import '../../core/models/permission_status.dart';
import '../../core/utils/logger.dart';
import 'platform_bridge.dart';
import 'web_host.dart';

/// Browser implementation of [PlatformBridge].
///
/// This is a preview harness for the browser. The browser cannot turn on a
/// display, cannot hold an Android keyguard, cannot acquire
/// `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, and cannot write `CallLog.Calls`. What it
/// *can* do — and what this class does — is drive the identical Dart state
/// machine through the identical screens, using the browser's own APIs
/// (`Notification`, `navigator.vibrate`, Web Audio, `localStorage`) where an
/// equivalent exists, and a manual sensor control where none does.
///
/// The web run therefore exercises every piece of app logic and every pixel of
/// the HyperOS clone. It is **not** evidence that the device behaviours in spec
/// §7 work, and the UI carries a persistent badge so that claim is never made
/// by accident.
class WebPreviewBridge implements PlatformBridge {
  WebPreviewBridge({Stream<bool>? proximitySource}) : _externalProximity =
      proximitySource {
    installKeyboardListener(_onHostKey);
  }

  final Stream<bool>? _externalProximity;

  final StreamController<bool> _proximity = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _launchController =
      StreamController<Map<String, dynamic>>.broadcast();

  Timer? _scheduledAlarmTimer;
  Map<String, dynamic>? _pendingLaunch;

  final List<String> _invocations = <String>[];

  /// Everything the bridge was asked to do — surfaced on the Setup page as the
  /// evidence that the web run is exercising the real code path.
  List<String> get invocations => List<String>.unmodifiable(_invocations);

  bool get ringerActive => _ringerActive;
  bool get vibrating => _vibrating;

  bool _ringerActive = false;
  bool _vibrating = false;

  @override
  PlatformKind get kind => PlatformKind.webPreview;

  @override
  bool get isHardwareBacked => false;

  void _record(String method) {
    _invocations.add(method);
    AppLogger.instance.info('web-bridge', method);
  }

  // ---------------------------------------------------------------- scheduling
  @override
  Future<bool> canScheduleExactAlarms() async {
    _record('canScheduleExactAlarms');
    return true;
  }

  @override
  Future<void> openExactAlarmSettings() async => _record('openExactAlarmSettings');

  @override
  Future<void> scheduleExactAlarm({
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) async {
    _record('scheduleExactAlarm@$triggerAtMs');
    _scheduledAlarmTimer?.cancel();
    final Duration delay = DateTime.fromMillisecondsSinceEpoch(
      triggerAtMs,
    ).difference(DateTime.now());
    _scheduledAlarmTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _record('alarmFired');
        unawaited(launchIncomingCall(payload: payload));
      },
    );
  }

  @override
  Future<void> cancelExactAlarm() async {
    _record('cancelExactAlarm');
    _scheduledAlarmTimer?.cancel();
    _scheduledAlarmTimer = null;
  }

  // ------------------------------------------------------- multiple schedules
  // A Map keyed by id, not a single Timer: the browser preview has to model
  // the same independence the native AlarmManager provides, or the timeline
  // would look correct here and collapse to one call on a device.
  final Map<String, Timer> _callTimers = <String, Timer>{};
  final Map<String, Map<String, dynamic>> _callPayloads =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> scheduleCall({
    required String id,
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) async {
    _record('scheduleCall:$id');
    _callTimers.remove(id)?.cancel();
    _callPayloads[id] = payload;
    final Duration delay = DateTime.fromMillisecondsSinceEpoch(
      triggerAtMs,
    ).difference(DateTime.now());
    _callTimers[id] = Timer(delay.isNegative ? Duration.zero : delay, () {
      _callTimers.remove(id);
      final Map<String, dynamic>? stored = _callPayloads.remove(id);
      if (stored != null) {
        unawaited(launchIncomingCall(payload: stored));
      }
    });
  }

  @override
  Future<void> cancelCall({required String id}) async {
    _record('cancelCall:$id');
    _callTimers.remove(id)?.cancel();
    _callPayloads.remove(id);
  }

  @override
  Future<List<Map<String, dynamic>>> listScheduledCalls() async {
    _record('listScheduledCalls');
    return _callPayloads.entries
        .map((MapEntry<String, Map<String, dynamic>> e) => <String, dynamic>{
          ...e.value,
          'id': e.key,
        })
        .toList(growable: false);
  }

  @override
  Future<void> clearScheduledCalls() async {
    _record('clearScheduledCalls');
    for (final Timer timer in _callTimers.values) {
      timer.cancel();
    }
    _callTimers.clear();
    _callPayloads.clear();
  }

  // ------------------------------------------------------------------ call UI
  @override
  Future<void> launchIncomingCall({
    required Map<String, dynamic> payload,
  }) async {
    _record('launchIncomingCall');
    _pendingLaunch = payload;
    // Emitted with the dispatcher event name so the ringing transition is
    // driven by the same code path the Android alarm drives.
    _launchController.add(<String, dynamic>{
      ...payload,
      'event': 'callIncoming',
    });
  }

  @override
  Future<void> setLockScreenTakeover({required bool enabled}) async =>
      _record('setLockScreenTakeover:$enabled');

  @override
  Future<void> hideOverlay() async => _record('hideOverlay');

  @override
  Future<void> setKeepScreenOn({required bool enabled}) async =>
      _record('setKeepScreenOn:$enabled');

  @override
  Future<void> setVoiceCommunicationMode({required bool enabled}) async =>
      _record('setVoiceCommunicationMode:$enabled');

  // ------------------------------------------------------------------- ringer
  @override
  Future<void> startRinger({required bool vibrate}) async {
    _record('startRinger(vibrate=$vibrate)');
    _ringerActive = true;
    _vibrating = vibrate;
    if (vibrate) {
      vibratePattern(<int>[0, 800, 800, 800]);
    }
  }

  @override
  Future<void> stopRinger() async {
    _record('stopRinger');
    _ringerActive = false;
    _vibrating = false;
    stopVibration();
  }

  @override
  Future<void> silenceRinger() async {
    _record('silenceRinger');
    _ringerActive = false;
    _vibrating = false;
    stopVibration();
  }

  @override
  Future<void> previewRinger() async {
    _record('previewRinger');
    vibratePattern(<int>[0, 300, 200, 300]);
  }

  // ---------------------------------------------------------------- proximity
  @override
  Stream<bool> get proximityStream {
    final Stream<bool>? external = _externalProximity;
    if (external == null) {
      return _proximity.stream;
    }
    return external;
  }

  @override
  Future<void> startProximityMonitoring() async =>
      _record('startProximityMonitoring');

  @override
  Future<void> stopProximityMonitoring() async =>
      _record('stopProximityMonitoring');

  /// Feeds the preview proximity sensor (the "hold to ear" control).
  void pushProximity(bool near) {
    _record('proximity:${near ? 'NEAR' : 'FAR'}');
    if (!_proximity.isClosed) {
      _proximity.add(near);
    }
  }

  // ---------------------------------------------------------------- call log
  @override
  Future<bool> writeNativeCallLog(Map<String, dynamic> entry) async {
    // A browser has no CallLog.Calls provider. Returning `false` is the honest
    // answer — the in-app DAO is what records the row on this platform.
    _record('writeNativeCallLog(no-provider)');
    return false;
  }

  // -------------------------------------------------------------- permissions
  @override
  Future<PermissionStatus> readPermissionStatus() async {
    _record('readPermissionStatus');
    return PermissionStatus.assumeAllGranted;
  }

  @override
  Future<void> openAppSettings() async => _record('openAppSettings');

  @override
  Future<void> openAutostartSettings() async => _record('openAutostartSettings');

  @override
  Future<void> openNotificationSettings() async =>
      _record('openNotificationSettings');

  // ------------------------------------------------------------------ launch
  @override
  Stream<Map<String, dynamic>> get launchTriggerStream => _launchController.stream;

  @override
  Future<Map<String, dynamic>?> consumeLaunchIntent() async => _pendingLaunch;

  // --------------------------------------------------------------- internals
  void _onHostKey(String key) {
    _record('hostKey:$key');
    _launchController.add(<String, dynamic>{
      'event': 'volumeKeyPressed',
      'key': key,
    });
  }

  @override
  Future<void> dispose() async {
    _scheduledAlarmTimer?.cancel();
    _scheduledAlarmTimer = null;
    stopVibration();
    await _proximity.close();
    await _launchController.close();
  }
}
