import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/models/permission_status.dart';
import '../../core/utils/logger.dart';
import 'platform_bridge.dart';

/// Android implementation of [PlatformBridge], backed by Kotlin through a
/// single `MethodChannel` plus two `EventChannel`s.
///
/// The contract is *total*: an unsupported call returns a null/false result and
/// logs the reason rather than throwing, so a device missing an OEM permission
/// degrades instead of crashing the call flow.
class MethodChannelBridge implements PlatformBridge {
  MethodChannelBridge({
    required MethodChannel channel,
    required EventChannel proximityChannel,
    required EventChannel launchChannel,
    void Function(Map<String, dynamic>? payload)? onLaunchPayload,
  }) : _channel = channel,
       _proximityChannel = proximityChannel,
       _launchChannel = launchChannel,
       _onLaunchPayload = onLaunchPayload {
    _launchSub = _launchChannel.receiveBroadcastStream().listen(
      (Object? event) {
        if (event is Map) {
          final Map<String, dynamic> payload = Map<String, dynamic>.from(event);
          AppLogger.instance.info('bridge', 'launch intent $payload');
          _onLaunchPayload?.call(payload);
          _launchController.add(payload);
        }
      },
      onError: (Object error) {
        AppLogger.instance.error('bridge', 'launch stream error: $error');
      },
    );
  }

  final MethodChannel _channel;
  final EventChannel _proximityChannel;
  final EventChannel _launchChannel;
  final void Function(Map<String, dynamic>? payload)? _onLaunchPayload;

  final StreamController<bool> _proximity = StreamController<bool>.broadcast();
  final StreamController<Map<String, dynamic>> _launchController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Object?>? _launchSub;
  StreamSubscription<Object?>? _proximitySub;

  @override
  PlatformKind get kind => PlatformKind.android;

  @override
  bool get isHardwareBacked => true;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      final T? result = await _channel.invokeMethod<T>(method, args);
      AppLogger.instance.info('channel', '$method -> $result');
      return result;
    } on PlatformException catch (error) {
      AppLogger.instance.error(
        'channel',
        '$method failed: ${error.code} ${error.message}',
      );
      return null;
    } on MissingPluginException {
      AppLogger.instance.warn('channel', '$method unavailable (no plugin)');
      return null;
    }
  }

  // ---------------------------------------------------------------- scheduling
  @override
  Future<bool> canScheduleExactAlarms() async {
    final bool? granted = await _invoke<bool>('canScheduleExactAlarms');
    return granted ?? false;
  }

  @override
  Future<void> openExactAlarmSettings() async =>
      _invoke<void>('openExactAlarmSettings');

  @override
  Future<void> scheduleExactAlarm({
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) {
    return _invoke<void>('scheduleExactAlarm', <String, dynamic>{
      'triggerAtMs': triggerAtMs,
      'payload': payload,
    });
  }

  @override
  Future<void> cancelExactAlarm() async => _invoke<void>('cancelExactAlarm');
  // ------------------------------------------------------- multiple schedules
  @override
  Future<void> scheduleCall({
    required String id,
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  }) {
    return _invoke<void>('scheduleCall', <String, dynamic>{
      'id': id,
      'triggerAtMs': triggerAtMs,
      'payload': payload,
    });
  }

  @override
  Future<void> cancelCall({required String id}) =>
      _invoke<void>('cancelCall', <String, dynamic>{'id': id});

  @override
  Future<List<Map<String, dynamic>>> listScheduledCalls() async {
    final List<Object?>? raw = await _invoke<List<Object?>>('listScheduledCalls');
    if (raw == null) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  @override
  Future<void> clearScheduledCalls() => _invoke<void>('clearScheduledCalls');
  // ------------------------------------------------------------------ call UI
  @override
  Future<void> launchIncomingCall({
    required Map<String, dynamic> payload,
  }) {
    return _invoke<void>('launchIncomingCall', <String, dynamic>{
      'payload': payload,
    });
  }

  @override
  Future<void> setLockScreenTakeover({required bool enabled}) {
    return _invoke<void>('setLockScreenTakeover', <String, dynamic>{
      'enabled': enabled,
    });
  }

  @override
  Future<void> hideOverlay() async => _invoke<void>('hideOverlay');

  @override
  Future<void> setKeepScreenOn({required bool enabled}) {
    return _invoke<void>('setKeepScreenOn', <String, dynamic>{'enabled': enabled});
  }

  @override
  Future<void> setVoiceCommunicationMode({required bool enabled}) {
    return _invoke<void>('setVoiceCommunicationMode', <String, dynamic>{
      'enabled': enabled,
    });
  }

  // ------------------------------------------------------------------- ringer
  @override
  Future<void> startRinger({required bool vibrate}) {
    return _invoke<void>('startRinger', <String, dynamic>{'vibrate': vibrate});
  }

  @override
  Future<void> stopRinger() async => _invoke<void>('stopRinger');

  @override
  Future<void> silenceRinger() async => _invoke<void>('silenceRinger');

  @override
  Future<void> previewRinger() async => _invoke<void>('previewRinger');

  // ---------------------------------------------------------------- proximity
  @override
  Stream<bool> get proximityStream {
    _proximitySub ??= _proximityChannel.receiveBroadcastStream().listen(
      (Object? event) {
        _proximity.add(event == true);
      },
      onError: (Object error) {
        AppLogger.instance.error('bridge', 'proximity stream error: $error');
      },
    );
    return _proximity.stream;
  }

  @override
  Future<void> startProximityMonitoring() async {
    _proximitySub ??= _proximityChannel.receiveBroadcastStream().listen(
      (Object? event) => _proximity.add(event == true),
      onError: (Object error) {
        AppLogger.instance.error('bridge', 'proximity stream error: $error');
      },
    );
    await _invoke<void>('startProximityMonitoring');
  }

  @override
  Future<void> stopProximityMonitoring() async =>
      _invoke<void>('stopProximityMonitoring');

  // ---------------------------------------------------------------- call log
  @override
  Future<bool> writeNativeCallLog(Map<String, dynamic> entry) async {
    final bool? written = await _invoke<bool>('writeNativeCallLog', entry);
    return written ?? false;
  }

  // -------------------------------------------------------------- permissions
  @override
  Future<PermissionStatus> readPermissionStatus() async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('readPermissionStatus');
    if (raw == null) {
      return const PermissionStatus();
    }
    final Map<String, bool> granted = <String, bool>{
      for (final MapEntry<Object?, Object?> e in raw.entries)
        '${e.key}': e.value == true,
    };
    return PermissionStatus(granted: granted);
  }

  @override
  Future<void> openAppSettings() async => _invoke<void>('openAppSettings');

  @override
  Future<void> openAutostartSettings() async =>
      _invoke<void>('openAutostartSettings');

  @override
  Future<void> openNotificationSettings() async =>
      _invoke<void>('openNotificationSettings');

  // ------------------------------------------------------------------ launch
  @override
  Stream<Map<String, dynamic>> get launchTriggerStream => _launchController.stream;

  @override
  Future<Map<String, dynamic>?> consumeLaunchIntent() async {
    final Map<Object?, Object?>? raw =
        await _invoke<Map<Object?, Object?>>('consumeLaunchIntent');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> dispose() async {
    await _launchSub?.cancel();
    await _proximitySub?.cancel();
    await _proximity.close();
    await _launchController.close();
  }
}
