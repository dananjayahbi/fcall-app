import 'dart:async';

import '../../core/models/permission_status.dart';

/// Which concrete [PlatformBridge] is in use.
enum PlatformKind {
  android,

  /// Browser preview harness.
  webPreview,

  /// Unit tests / desktop — every hardware call is a recorded no-op.
  headless,
}

/// Payload keys shared with the native Kotlin side (`CallSessionStore`).
abstract final class CallPayloadKeys {
  static const String sessionId = 'sessionId';
  static const String name = 'name';
  static const String number = 'number';
  static const String simLabel = 'simLabel';
  static const String vibrate = 'vibrate';
  static const String ringerSilent = 'ringerSilent';
  static const String launchSource = 'launchSource';
}

/// The single seam between app logic and device hardware.
///
/// Everything above this interface (screens, controllers, services) is pure
/// Dart and runs identically on Android and on the web. Everything below it is
/// the only place that knows whether it is talking to a real Xiaomi handset or
/// to a browser simulation.
///
/// Implementations must be **total**: a method that cannot be honoured on the
/// current platform records the reason in [AppLogger] and returns normally. It
/// must never throw for a missing capability, because a web run and a device run
/// share the same call flow and a throw would diverge them.
abstract class PlatformBridge {
  PlatformKind get kind;

  /// True when hardware-backed behaviour is genuinely available.
  bool get isHardwareBacked;

  // ---------------------------------------------------------------- scheduling
  /// Android 13+ exact-alarm consent. Always `true` off Android.
  Future<bool> canScheduleExactAlarms();

  /// Deep-link to the "Alarms & reminders" system screen.
  Future<void> openExactAlarmSettings();

  /// Register a wake-up at [triggerAtMs] (epoch ms) that survives Doze.
  Future<void> scheduleExactAlarm({
    required int triggerAtMs,
    required Map<String, dynamic> payload,
  });

  Future<void> cancelExactAlarm();

  // ------------------------------------------------------------------ call UI
  /// Present the incoming-call takeover: full-screen intent when locked,
  /// heads-up notification when unlocked.
  Future<void> launchIncomingCall({required Map<String, dynamic> payload});

  /// `showWhenLocked` + `turnScreenOn` + `setShowWhenLocked` + keyguard dismiss.
  Future<void> setLockScreenTakeover({required bool enabled});

  Future<void> hideOverlay();

  Future<void> setKeepScreenOn({required bool enabled});

  /// Switch the audio manager to `MODE_IN_COMMUNICATION` while a call is up.
  Future<void> setVoiceCommunicationMode({required bool enabled});

  // ------------------------------------------------------------------- ringer
  Future<void> startRinger({required bool vibrate});

  /// Immediate stop with no audio tail.
  Future<void> stopRinger();

  /// Volume-key policy: mute the ringer, keep the call screen up.
  Future<void> silenceRinger();

  /// Short preview of the configured ringtone (config screen "test" button).
  Future<void> previewRinger();

  // ---------------------------------------------------------------- proximity
  /// Near/far stream from the proximity sensor. `true` = object detected.
  Stream<bool> get proximityStream;

  /// Bind the hardware `PROXIMITY_SCREEN_OFF_WAKE_LOCK`.
  Future<void> startProximityMonitoring();

  Future<void> stopProximityMonitoring();

  // ---------------------------------------------------------------- call log
  /// Module 6 — insert a row into Android's native `CallLog.Calls`.
  Future<bool> writeNativeCallLog(Map<String, dynamic> entry);

  // -------------------------------------------------------------- permissions
  Future<PermissionStatus> readPermissionStatus();

  Future<void> openAppSettings();

  Future<void> openAutostartSettings();

  Future<void> openNotificationSettings();

  // ------------------------------------------------------------------ launch
  /// Emits when the app is cold-started by the quick-action shortcut/tile.
  Stream<Map<String, dynamic>> get launchTriggerStream;

  /// One-shot value of the launch intent, consumed on first frame.
  Future<Map<String, dynamic>?> consumeLaunchIntent();

  Future<void> dispose();
}
