import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models/permission_status.dart';
import '../../core/utils/logger.dart';
import 'method_channel_bridge.dart';
import 'platform_bridge.dart';
import 'web_bridge.dart';

/// Locates and holds the single [PlatformBridge] for the process.
///
/// The selection is explicit and logged so a run can never be mistaken for a
/// platform other than the one it actually is.
class BridgeService {
  BridgeService._();

  static final BridgeService instance = BridgeService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.mobiletel.incomingcall/bridge',
  );

  static const EventChannel _proximityChannel = EventChannel(
    'com.mobiletel.incomingcall/proximity',
  );

  static const EventChannel _launchChannel = EventChannel(
    'com.mobiletel.incomingcall/launch',
  );

  PlatformBridge? _bridge;
  Map<String, dynamic>? _pendingLaunch;

  PlatformBridge get bridge => _bridge ??= _create();

  /// Called from `main()` before the first frame so that a cold start
  /// triggered by a quick-action tile can pick up its payload.
  void setPendingLaunchPayload(Map<String, dynamic>? payload) {
    if (payload != null && payload.isNotEmpty) {
      _pendingLaunch = payload;
    }
  }

  /// The launch payload captured before the first frame, if any.
  ///
  /// Read once: consuming it here prevents the quick-action trigger from
  /// re-arming a second call every time the screen is rebuilt.
  Map<String, dynamic>? takePendingLaunch() {
    final Map<String, dynamic>? payload = _pendingLaunch;
    _pendingLaunch = null;
    return payload;
  }

  PlatformBridge _create() {
    final PlatformBridge created;
    if (kIsWeb) {
      created = WebPreviewBridge();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      created = MethodChannelBridge(
        channel: _methodChannel,
        proximityChannel: _proximityChannel,
        launchChannel: _launchChannel,
        onLaunchPayload: setPendingLaunchPayload,
      );
    } else {
      created = HeadlessBridge();
    }
    AppLogger.instance.info(
      'bridge',
      'platform=${created.kind.name} hardware=${created.isHardwareBacked}',
    );
    return created;
  }
}

/// Fallback used on desktop and in unit tests: every hardware call is recorded
/// and dropped so logic tests can exercise the full call flow deterministically.
class HeadlessBridge implements PlatformBridge {
  final List<String> _calls = <String>[];
  final StreamController<bool> _proximity = StreamController<bool>.broadcast();

  List<String> get calls => List<String>.unmodifiable(_calls);

  @override
  PlatformKind get kind => PlatformKind.headless;

  @override
  bool get isHardwareBacked => false;

  void _record(String method) {
    _calls.add(method);
    AppLogger.instance.info('headless-bridge', method);
  }

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> openExactAlarmSettings() async => _record('openExactAlarmSettings');

  @override
  Future<void> scheduleExactAlarm({
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) async => _record('scheduleExactAlarm@$triggerAtMs');

  @override
  Future<void> cancelExactAlarm() async => _record('cancelExactAlarm');

  @override
  Future<void> scheduleCall({
    required String id,
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) async => _record('scheduleCall:$id');

  @override
  Future<void> cancelCall({required String id}) async => _record('cancelCall:$id');

  @override
  Future<List<Map<String, dynamic>>> listScheduledCalls() async {
    _record('listScheduledCalls');
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<void> clearScheduledCalls() async => _record('clearScheduledCalls');

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
      _record('startRinger(vibrate=$vibrate)');

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

  @override
  Future<bool> writeNativeCallLog(Map<String, dynamic> entry) async {
    _record('writeNativeCallLog');
    return false;
  }

  @override
  Future<PermissionStatus> readPermissionStatus() async =>
      PermissionStatus.assumeAllGranted;

  @override
  Future<void> openAppSettings() async => _record('openAppSettings');

  @override
  Future<void> openAutostartSettings() async => _record('openAutostartSettings');

  @override
  Future<void> openNotificationSettings() async =>
      _record('openNotificationSettings');

  @override
  Stream<Map<String, dynamic>> get launchTriggerStream =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<Map<String, dynamic>?> consumeLaunchIntent() async => null;

  @override
  Future<void> dispose() async {
    await _proximity.close();
  }
}
