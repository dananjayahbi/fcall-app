import 'dart:async';

import 'package:incoming_call/core/models/permission_status.dart';
import 'package:incoming_call/services/platform/platform_bridge.dart';

/// A recording [PlatformBridge] for tests.
///
/// It records the exact ordered sequence of hardware calls, which is the only
/// way to assert the *ordering* requirements in the spec (ringtone stops
/// **before** proximity starts; locks are released **before** the call is
/// logged). A test that only checked the final state would pass even if the
/// order were reversed, which is the failure mode that leaves a device holding
/// a proximity wake lock.
class FakeBridge implements PlatformBridge {
  final List<String> calls = <String>[];
  final StreamController<bool> _proximity = StreamController<bool>.broadcast();

  /// Drives [launchTriggerStream] so a test can simulate the native launch
  /// EventChannel delivering an event. Without this the stream is inert and the
  /// dispatcher cannot be exercised at all.
  final StreamController<Map<String, dynamic>> _launch =
      StreamController<Map<String, dynamic>>.broadcast();

  bool canSchedule = true;
  bool nativeCallLogAccepts = true;
  PermissionStatus permissionStatus = PermissionStatus.assumeAllGranted;

  /// Set to fire a launch event when the alarm "fires".
  Map<String, dynamic>? pendingLaunch;

  /// Simulates the native layer announcing a launch event.
  void emitLaunch(Map<String, dynamic> event) => _launch.add(event);

  @override
  PlatformKind get kind => PlatformKind.headless;

  @override
  bool get isHardwareBacked => false;

  void _record(String entry) => calls.add(entry);

  int countOf(String prefix) =>
      calls.where((String c) => c.startsWith(prefix)).length;

  int indexOf(String entry) => calls.indexOf(entry);

  @override
  Future<bool> canScheduleExactAlarms() async {
    _record('canScheduleExactAlarms');
    return canSchedule;
  }

  @override
  Future<void> openExactAlarmSettings() async => _record('openExactAlarmSettings');

  @override
  Future<void> scheduleExactAlarm({
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) async {
    _record('scheduleExactAlarm');
    lastPayload = payload;
  }

  Map<String, dynamic>? lastPayload;

  @override
  Future<void> cancelExactAlarm() async => _record('cancelExactAlarm');

  @override
  Future<void> launchIncomingCall({
    required Map<String, dynamic> payload,
  }) async => _record('launchIncomingCall');

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

  @override
  Future<void> startRinger({required bool vibrate}) async =>
      _record('startRinger:$vibrate');

  @override
  Future<void> stopRinger() async => _record('stopRinger');

  @override
  Future<void> silenceRinger() async => _record('silenceRinger');

  @override
  Future<void> previewRinger() async => _record('previewRinger');

  @override
  Stream<bool> get proximityStream => _proximity.stream;

  @override
  Future<void> startProximityMonitoring() async =>
      _record('startProximityMonitoring');

  @override
  Future<void> stopProximityMonitoring() async =>
      _record('stopProximityMonitoring');

  void pushProximity(bool near) => _proximity.add(near);

  @override
  Future<bool> writeNativeCallLog(Map<String, dynamic> entry) async {
    _record('writeNativeCallLog');
    lastCallLogEntry = entry;
    return nativeCallLogAccepts;
  }

  Map<String, dynamic>? lastCallLogEntry;

  @override
  Future<PermissionStatus> readPermissionStatus() async {
    _record('readPermissionStatus');
    return permissionStatus;
  }

  @override
  Future<void> openAppSettings() async => _record('openAppSettings');

  @override
  Future<void> openAutostartSettings() async => _record('openAutostartSettings');

  @override
  Future<void> openNotificationSettings() async =>
      _record('openNotificationSettings');

  @override
  Stream<Map<String, dynamic>> get launchTriggerStream => _launch.stream;

  @override
  Future<Map<String, dynamic>?> consumeLaunchIntent() async => pendingLaunch;

  @override
  Future<void> dispose() async {
    await _proximity.close();
    await _launch.close();
  }
}
