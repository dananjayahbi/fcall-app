import 'dart:async';

import '../../core/utils/logger.dart';
import '../platform/bridge_service.dart';
import '../platform/platform_bridge.dart';

/// Module 5: binds the proximity sensor to the display policy.
///
/// `true` means an object is near (phone at the ear) → the native side holds
/// `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, which shuts the panel off and drops touch.
/// `false` releases it and the screen comes back.
///
/// The screen state is **not** faked in Dart. Dart only observes; the actual
/// panel-off is a hardware wake lock on Android, which is what spec §5
/// explicitly requires instead of a software black overlay.
class ProximityService {
  ProximityService({PlatformBridge? bridge})
    : _bridge = bridge ?? BridgeService.instance.bridge;

  final PlatformBridge _bridge;

  final StreamController<bool> _nearController = StreamController<bool>.broadcast();

  StreamSubscription<bool>? _subscription;
  bool _monitoring = false;
  bool _isNear = false;

  bool get isNear => _isNear;
  bool get isMonitoring => _monitoring;
  Stream<bool> get nearStream => _nearController.stream;

  /// Begins monitoring. Idempotent — a second call does not double-bind the
  /// sensor listener, which on Android would double-deliver every event.
  Future<void> start() async {
    if (_monitoring) return;
    _monitoring = true;
    _subscription = _bridge.proximityStream.listen(_onEvent);
    await _bridge.startProximityMonitoring();
    AppLogger.instance.info('proximity', 'monitoring started');
  }

  void _onEvent(bool near) {
    if (near == _isNear) return;
    _isNear = near;
    AppLogger.instance.info('proximity', near ? 'NEAR (ear)' : 'FAR');
    if (!_nearController.isClosed) _nearController.add(near);
  }

  Future<void> stop() async {
    if (!_monitoring) return;
    _monitoring = false;
    await _subscription?.cancel();
    _subscription = null;
    await _bridge.stopProximityMonitoring();
    _isNear = false;
    AppLogger.instance.info('proximity', 'monitoring stopped');
  }

  Future<void> dispose() async {
    await stop();
    await _nearController.close();
  }
}
