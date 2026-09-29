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
        Log.i(TAG, "Alarm fired: ${intent.action}")
        val serviceIntent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_START
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

    private companion object {
        const val TAG = "CallAlarmReceiver"
    }
}
