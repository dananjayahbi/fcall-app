package com.mobiletel.incomingcall.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.mobiletel.incomingcall.platform.PrefKeys
import com.mobiletel.incomingcall.platform.ScheduleStore

/**
 * Module 2 — exact alarm registration for *many* concurrent calls.
 *
 * ## The single-request-code defect
 *
 * The previous scheduler used one hard-coded request code. `PendingIntent`
 * equality ignores extras and is decided by (action, data, component, request
 * code), so every call produced the **same** `PendingIntent`: registering a
 * second alarm replaced the first rather than adding to it. The user could
 * only ever have one scheduled call, and the app's own timeline would have been
 * lying about it.
 *
 * The fix is one request code per schedule id, derived from the id's hash with
 * the range trimmed to a positive `Int`. Ids are generated as
 * `<microseconds>-<counter>`, so collisions are not a practical concern, and a
 * collision would merely overwrite one schedule — the same behaviour as before
 * — rather than crash.
 *
 * `setExactAndAllowWhileIdle` remains the only variant used: `setExact` does
 * not fire through Doze, and on Android 12+ it is deferred, which is the single
 * most common failure for a call-alert utility.
 */
object CallAlarmSchedulerV2 {

    private const val TAG = "CallAlarmSchedulerV2"
    const val ACTION_CALL_ALARM = "com.mobiletel.incomingcall.action.CALL_ALARM"
    const val EXTRA_SCHEDULE_ID = "com.mobiletel.incomingcall.SCHEDULE_ID"

    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return false
        return manager.canScheduleExactAlarms()
    }

    /**
     * Stable per-schedule request code.
     *
     * `and Int.MAX_VALUE` keeps it positive; a negative code is legal but
     * collides with the other reserved range, and there is no reason to go
     * there.
     */
    fun requestCodeFor(scheduleId: String): Int =
        scheduleId.hashCode() and Int.MAX_VALUE

    fun schedule(context: Context, scheduleId: String, fireAtMs: Long, payload: Map<String, Any?>) {
        if (scheduleId.isEmpty()) {
            Log.e(TAG, "Refusing to schedule with an empty id")
            return
        }
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

        // Persist before registering: if the process dies between here and the
        // alarm firing, the receiver still has the payload to rebuild the call.
        val stored = HashMap(payload)
        stored["id"] = scheduleId
        stored[PrefKeys.FIRE_AT] = fireAtMs
        ScheduleStore.save(context, stored)

        val intent = Intent(context, CallAlarmReceiver::class.java).apply {
            action = ACTION_CALL_ALARM
            putExtra(EXTRA_SCHEDULE_ID, scheduleId)
            // Distinct data URI per schedule. Without this, two intents with the
            // same action and component are the *same* PendingIntent even with
            // different request codes on some OEM builds, so the extras-only
            // distinction is belt-and-braces.
            data = android.net.Uri.parse("incomingcall://call/$scheduleId")
        }
        val pending = PendingIntent.getBroadcast(
            context,
            requestCodeFor(scheduleId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        runCatching {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAtMs, pending)
            Log.i(TAG, "Armed '$scheduleId' for $fireAtMs (pending=${ScheduleStore.count(context)})")
        }.onFailure { error ->
            Log.e(TAG, "setExactAndAllowWhileIdle failed: ${error.message}")
        }
    }

    fun cancel(context: Context, scheduleId: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager != null) {
            val intent = Intent(context, CallAlarmReceiver::class.java).apply {
                action = ACTION_CALL_ALARM
                data = android.net.Uri.parse("incomingcall://call/$scheduleId")
            }
            val pending = PendingIntent.getBroadcast(
                context,
                requestCodeFor(scheduleId),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pending != null) {
                manager.cancel(pending)
                pending.cancel()
            }
        }
        ScheduleStore.delete(context, scheduleId)
        Log.i(TAG, "Cancelled '$scheduleId'")
    }

    /** Drops every armed call — used when a reboot re-arms the whole set. */
    fun rearmAll(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (manager == null) return
        val now = System.currentTimeMillis()
        var restored = 0
        for (entry in ScheduleStore.readAll(context)) {
            val id = entry.optString("id")
            if (id.isEmpty()) continue
            val fireAt = entry.optLong(PrefKeys.FIRE_AT, 0L)
            if (fireAt <= 0L) continue
            if (fireAt <= now) {
                // The trigger elapsed while the device was off. Fire now rather
                // than silently dropping it — that is what a real call does.
                Log.i(TAG, "'$id' elapsed during reboot; firing now")
                CallAlarmReceiver.dispatch(context, id)
                continue
            }
            schedule(context, id, fireAt, ScheduleStore.toMap(entry))
            restored++
        }
        Log.i(TAG, "Re-armed $restored pending call(s) after reboot")
    }
}
