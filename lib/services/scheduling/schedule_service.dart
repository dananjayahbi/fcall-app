import '../../core/models/call_trigger.dart';
import '../../core/utils/logger.dart';
import '../platform/bridge_service.dart';
import '../platform/platform_bridge.dart';

/// Result of a scheduling attempt, carrying a user-presentable reason when it
/// fails. The config screen renders [message] verbatim rather than inventing its
/// own error copy, so a native rejection never shows as a generic failure.
class ScheduleResult {
  const ScheduleResult.success(int this.fireAtMs)
    : ok = true,
      message = null;

  const ScheduleResult.failure(String this.message)
    : ok = false,
      fireAtMs = null;

  final bool ok;
  final String? message;
  final int? fireAtMs;
}

/// Module 2: validates a [CallTrigger] and routes it to the platform bridge.
///
/// Validation happens *before* the native call so a stale trigger is reported as
/// "pick a later time" rather than silently firing immediately.
class ScheduleService {
  ScheduleService({PlatformBridge? bridge})
    : _bridge = bridge ?? BridgeService.instance.bridge;

  final PlatformBridge _bridge;

  PlatformBridge get bridge => _bridge;

  Future<ScheduleResult> schedule({
    required CallTrigger trigger,
    required Map<String, dynamic> payload,
  }) async {
    if (!trigger.isValid()) {
      AppLogger.instance.warn('schedule', 'trigger already in the past');
      return const ScheduleResult.failure(
        'That time has already passed — pick a later one.',
      );
    }

    final bool canExact = await _bridge.canScheduleExactAlarms();
    if (!canExact) {
      AppLogger.instance.error('schedule', 'exact alarm permission denied');
      return const ScheduleResult.failure(
        'Android needs the "Alarms & reminders" permission before an exact '
        'call can be scheduled.',
      );
    }

    await _bridge.scheduleExactAlarm(
      triggerAtMs: trigger.fireAtMs,
      payload: payload,
    );
    AppLogger.instance.info(
      'schedule',
      'armed for ${trigger.fireAt} (${trigger.kind.name})',
    );
    return ScheduleResult.success(trigger.fireAtMs);
  }

  Future<void> cancel() async {
    await _bridge.cancelExactAlarm();
    AppLogger.instance.info('schedule', 'cancelled');
  }
}
