package com.mobiletel.incomingcall.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.mobiletel.incomingcall.alarm.CallAlarmScheduler
import com.mobiletel.incomingcall.service.IncomingCallService

/**
 * The manifest declares the alarm receiver under `.alarm.CallAlarmReceiver`,
 * but a `BroadcastReceiver` declared with an explicit component is only invoked
 * for that component class. This alias exists so the manifest can declare
 * `BOOT_COMPLETED` and the alarm action on one class while the alarm body
 * lives with the scheduling code.
 */
class CallAlarmReceiverAlias : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CallAlarmScheduler.ACTION_CALL_ALARM) {
            Log.w(TAG, "Unexpected action: ${intent.action}")
            return
        }
        val serviceIntent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_START
        }
        runCatching {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }.onFailure { Log.e(TAG, "startForegroundService failed: ${it.message}") }
    }

    private companion object {
        const val TAG = "AlarmAlias"
    }
}
