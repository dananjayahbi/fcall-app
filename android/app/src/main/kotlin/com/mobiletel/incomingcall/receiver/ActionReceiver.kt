package com.mobiletel.incomingcall.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.mobiletel.incomingcall.alarm.CallAlarmScheduler
import com.mobiletel.incomingcall.alarm.CallAlarmSchedulerV2
import com.mobiletel.incomingcall.platform.CallSessionStore
import com.mobiletel.incomingcall.platform.PrefKeys
import com.mobiletel.incomingcall.platform.ScheduleStore

/**
 * Module 2 — the quick-trigger entry point and the reboot rescheduler.
 *
 * Two jobs that are genuinely different and share a receiver:
 *
 *  1. `QUICK_RING` — the launcher shortcut / quick-settings tile. Registers a
 *     10 second alarm without opening the app, so the user can trigger a call
 *     from the home screen the way a real one arrives.
 *  2. `BOOT` — `AlarmManager` drops every registered alarm across a reboot. On
 *     a device that is asleep overnight, that is the difference between a call
 *     that fires and one that silently never does, so the pending trigger is
 *     re-armed on `BOOT_COMPLETED`.
 */
class ActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_QUICK_RING -> scheduleQuickRing(context)
            Intent.ACTION_BOOT_COMPLETED -> rearmAfterBoot(context)
            else -> Log.w(TAG, "Unhandled action: ${intent.action}")
        }
    }

    private fun scheduleQuickRing(context: Context) {
        val existing = CallSessionStore.readPayload(context)
        val payload = if (existing.isEmpty()) {
            mapOf(
                PrefKeys.NAME to "Unknown",
                PrefKeys.NUMBER to "",
                PrefKeys.SIM_LABEL to "SIM 1",
                PrefKeys.VIBRATE to true,
                PrefKeys.LAUNCH_SOURCE to "quick_action"
            )
        } else {
            existing + mapOf(PrefKeys.LAUNCH_SOURCE to "quick_action")
        }
        val fireAt = System.currentTimeMillis() + QUICK_DELAY_MS
        CallAlarmScheduler.schedule(context, fireAt, payload)
        Log.i(TAG, "Quick ring armed for +${QUICK_DELAY_MS}ms")
    }

    /**
     * `AlarmManager` drops every registered alarm across a reboot, so the whole
     * pending set has to be re-armed. With several calls armed this is no
     * longer "re-arm the one" — the previous version handled exactly one
     * fire time and would have silently dropped the rest.
     */
    private fun rearmAfterBoot(@Suppress("UNUSED_PARAMETER") context: Context) {
        val pending = ScheduleStore.count(context)
        if (pending == 0) return
        Log.i(TAG, "Re-arming $pending pending call(s) after reboot")
        CallAlarmSchedulerV2.rearmAll(context)
    }

    companion object {
        private const val TAG = "ActionReceiver"
        const val ACTION_QUICK_RING = "com.mobiletel.incomingcall.action.QUICK_RING"
        private const val QUICK_DELAY_MS = 10_000L
    }
}
