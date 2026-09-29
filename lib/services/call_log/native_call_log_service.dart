import '../../core/models/call_outcome.dart';
import '../../core/models/call_session.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/call_log_store.dart';
import '../platform/bridge_service.dart';
import '../platform/platform_bridge.dart';

/// Outcome of persisting a call, so the UI can say precisely what happened
/// instead of assuming the native write landed.
class CallLogWriteResult {
  const CallLogWriteResult({
    required this.appRowStored,
    required this.nativeWritten,
    this.nativeMessage = '',
  });

  /// The in-app DAO row always lands.
  final bool appRowStored;

  /// Whether Android's `CallLog.Calls` accepted the row. `false` off Android.
  final bool nativeWritten;
  final String nativeMessage;

  bool get persisted => appRowStored || nativeWritten;
}

/// Module 6 + Phase 5.1 — records a finished call.
///
/// Two independent writes happen here, and the difference matters:
///  * **native** — Android's `CallLog.Calls` provider. This is the spec
///    requirement: the record must appear in the Xiaomi Phone app.
///  * **in-app DAO** — always written, on every platform, so the behaviour is
///    observable in the web build (which has no call-log provider) and so the
///    history screen can render immediately.
///
/// The service reports which of the two succeeded rather than assuming.
class NativeCallLogService {
  NativeCallLogService({
    required CallLogStore dao,
    PlatformBridge? bridge,
  }) : _dao = dao,
       _bridge = bridge ?? BridgeService.instance.bridge;

  final CallLogStore _dao;
  final PlatformBridge _bridge;

  Future<List<SimCallLogEntry>> history() => _dao.load();

  Future<CallLogWriteResult> record(CallSession session) async {
    final SimCallLogEntry entry = SimCallLogEntry.fromSession(session);
    await _dao.append(entry);

    bool nativeWritten = false;
    String message;
    try {
      nativeWritten = await _bridge.writeNativeCallLog(entry.toJson());
      message = nativeWritten
          ? 'Written to system Call log'
          : 'No system call-log provider on this platform';
    } on Object catch (error) {
      message = 'Native call log write failed: $error';
      AppLogger.instance.error('call-log', message);
    }

    AppLogger.instance.info(
      'call-log',
      '${entry.displayType} ${entry.number} '
      'appRow=true native=$nativeWritten',
    );

    return CallLogWriteResult(
      appRowStored: true,
      nativeWritten: nativeWritten,
      nativeMessage: message,
    );
  }

  Future<void> clear() => _dao.clear();
}
