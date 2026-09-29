package com.mobiletel.incomingcall.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.mobiletel.incomingcall.service.IncomingCallService

/**
 * Module 2 — the alarm entry point.
 *
 * Starting a foreground service is mandatory here: on Android 8+ a background
 * `startActivity` is silently dropped, so the call screen would never appear.
 * The service then decides between a full-screen intent (device locked) and a
 * heads-up notification (device unlocked), per Module 2's contract.
 */
class CallAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getStringExtra(CallAlarmSchedulerV2.EXTRA_SCHEDULE_ID).orEmpty()
        Log.i(TAG, "Alarm fired: ${intent.action} (id='$scheduleId')")
        dispatch(context, scheduleId)
    }

    companion object {
        private const val TAG = "CallAlarmReceiver"

        /**
         * Starts the call service for [scheduleId].
         *
         * In a companion rather than an instance method so the reboot rescheduler
         * can fire an elapsed call without having to construct a receiver.
         */
        fun dispatch(context: Context, scheduleId: String) {
            val serviceIntent = Intent(context, IncomingCallService::class.java).apply {
                action = IncomingCallService.ACTION_START
                putExtra(CallAlarmSchedulerV2.EXTRA_SCHEDULE_ID, scheduleId)
            }
            runCatching {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }.onFailure { error ->
                Log.e(TAG, "Could not start the incoming-call service: ${error.message}")
            }
        }
    }
}
