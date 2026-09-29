package com.mobiletel.incomingcall.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.mobiletel.incomingcall.platform.CallSessionStore
import com.mobiletel.incomingcall.receiver.ActionReceiver

/**
 * Module 2 — exact alarm registration.
 *
 * `setExactAndAllowWhileIdle` is the only variant that fires through Doze.
 * `setExact` does not, and on Android 12+ it is deferred in favour of
 * inexact timing; the practical result is a call that arrives minutes late,
 * which is the single most common failure for a call-alert utility.
 */
object CallAlarmScheduler {

    private const val TAG = "CallAlarmScheduler"
    const val ACTION_CALL_ALARM = "com.mobiletel.incomingcall.action.CALL_ALARM"
    private const val REQUEST_CODE = 4711

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        return manager.canScheduleExactAlarms()
    }

    fun schedule(context: Context, triggerAtMs: Long, payload: Map<String, Any?>) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager == null) {
            Log.e(TAG, "AlarmManager unavailable")
            return
        }
        if (!canScheduleExact(context)) {
            Log.e(
                TAG,
                "Exact alarm permission denied; the call may fire late. " +
                    "The user must grant Alarms & reminders."
            )
        }

        // Persist first: if the process dies between here and the alarm firing,
        // the receiver still has the payload to rebuild the call screen.
        CallSessionStore.save(context, payload, triggerAtMs)

        val intent = Intent(context, CallAlarmReceiver::class.java).apply {
            action = ACTION_CALL_ALARM
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        runCatching {
            manager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMs,
                pending
            )
            Log.i(TAG, "Exact alarm registered for $triggerAtMs")
        }.onFailure { error ->
            Log.e(TAG, "setExactAndAllowWhileIdle failed: ${error.message}")
        }
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        val intent = Intent(context, CallAlarmReceiver::class.java).apply {
            action = ACTION_CALL_ALARM
        }
        val pending = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pending != null) {
            manager.cancel(pending)
            pending.cancel()
            Log.i(TAG, "Alarm cancelled")
        }
        CallSessionStore.clear(context)
    }
}
