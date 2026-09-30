import 'dart:async';

import '../core/utils/logger.dart';
import 'call_orchestrator.dart';
import 'platform/bridge_service.dart';
import 'platform/platform_bridge.dart';

/// Translates platform launch events into call-flow actions.
///
/// The bridge emits one undifferentiated stream for three different things
/// that all arrive through the same door:
///
///  * a volume-key press (Module 4) — silence the ringer
///  * the alarm firing (Module 2)   — start ringing
///  * the quick-action tile (Module 2 fallback) — arm a 10s countdown
///
/// Routing them here rather than in each page is what makes the flow
/// work identically whether the app is foreground, background, or was
/// cold-started by a `BroadcastReceiver` with no page alive. The previous
/// arrangement subscribed inside the pages, which meant an alarm that fired
/// while no page was mounted produced an event nobody handled — the call
/// never rang.
class LaunchDispatcher {
  LaunchDispatcher({required CallOrchestrator orchestrator, PlatformBridge? bridge})
    : _orchestrator = orchestrator,
      _bridge = bridge ?? BridgeService.instance.bridge;

  final CallOrchestrator _orchestrator;
  final PlatformBridge _bridge;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _started = false;

  /// Idempotent: a second call does not double-subscribe, which would ring
  /// the same call twice when both the alarm and the quick action fire.
  void start() {
    if (_started) return;
    _started = true;
    _subscription = _bridge.launchTriggerStream.listen(
      dispatch,
      onError: (Object error) {
        AppLogger.instance.error('launch-dispatch', 'stream error: $error');
      },
    );
  }

  Future<void> dispatch(Map<String, dynamic> event) async {
    final String kind = _eventNameOf(event);
    switch (kind) {
      case eventVolumeKey:
        await _orchestrator.onVolumeKeyPressed();

      case eventCall:
        final String name = _stringOf(event, keyName);
        final String number = _stringOf(event, keyNumber);
        if (name.trim().isEmpty) {
          // Logged rather than rendered silently. A missing name is a payload
          // that failed to survive the trip from the schedule to the ring
          // screen, and the only way to find where it was lost is this line —
          // the screen itself can only show a generic fallback.
          AppLogger.instance.warn(
            'launch-dispatch',
            'callIncoming carried no name (number="$number", '
            'schedule=${event['scheduleId']})',
          );
        }
        await _orchestrator.beginRinging(
          name: name,
          number: number,
          simLabel: _stringOf(event, keySimLabel, fallback: defaultSimLabel),
        );

      case eventQuickRing:
        final result = await _orchestrator.armQuickAction();
        if (!result.ok) {
          AppLogger.instance.warn('launch-dispatch', result.message ?? 'quick trigger failed');
        }

      default:
        AppLogger.instance.info('launch-dispatch', 'ignoring event "$kind"');
    }
  }

  /// Resolves the event name, tolerating the alternate key the native side has
  /// used for it.
  ///
  /// The event discriminator is duplicated in Kotlin (`LaunchSignalRelay`) and
  /// this class agrees on it only by convention — a mismatch is silent, it just
  /// drops the event, and the symptom ("the phone rang but nothing appeared")
  /// points nowhere near the cause. Reading both spellings turns that class of
  /// bug into a log line instead of a mystery.
  static String _eventNameOf(Map<String, dynamic> event) {
    final Object? primary = event[keyEvent];
    if (primary is String && primary.isNotEmpty) return primary;
    final Object? alternate = event['type'];
    if (alternate is String && alternate.isNotEmpty) return alternate;
    return '';
  }

  /// Non-throwing read: a missing or wrongly-typed key must not abort a call.
  static String _stringOf(
    Map<String, dynamic> event,
    String key, {
    String fallback = '',
  }) {
    final Object? value = event[key];
    if (value is String) return value;
    if (value == null) return fallback;
    return value.toString();
  }

  /// The alarm payload uses different keys from the quick-action payload, so
  /// both shapes are normalised here rather than at each call site.
  static const String keyEvent = 'event';
  static const String keyName = 'name';
  static const String keyNumber = 'number';
  static const String keySimLabel = 'simLabel';

  static const String defaultSimLabel = 'SIM 1';

  static const String eventVolumeKey = 'volumeKeyPressed';
  static const String eventCall = 'callIncoming';
  static const String eventQuickRing = 'quickRing';

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
