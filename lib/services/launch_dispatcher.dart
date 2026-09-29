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
    final String kind = (event['event'] ?? event[keyEvent] ?? '') as String;
    switch (kind) {
      case eventVolumeKey:
        await _orchestrator.onVolumeKeyPressed();

      case eventCall:
        await _orchestrator.beginRinging(
          name: (event[keyName] ?? '') as String,
          number: (event[keyNumber] ?? '') as String,
          simLabel: (event[keySimLabel] ?? 'SIM 1') as String,
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

  /// The alarm payload uses different keys from the quick-action payload, so
  /// both shapes are normalised here rather than at each call site.
  static const String keyEvent = 'event';
  static const String keyName = 'name';
  static const String keyNumber = 'number';
  static const String keySimLabel = 'simLabel';

  static const String eventVolumeKey = 'volumeKeyPressed';
  static const String eventCall = 'callIncoming';
  static const String eventQuickRing = 'quickRing';

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
