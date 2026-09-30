package com.mobiletel.incomingcall.service

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.mobiletel.incomingcall.MainActivity
import com.mobiletel.incomingcall.alarm.CallAlarmSchedulerV2
import com.mobiletel.incomingcall.platform.ActiveCallStore
import com.mobiletel.incomingcall.platform.CallPayloadResolver
import com.mobiletel.incomingcall.platform.MainActivityAction
import com.mobiletel.incomingcall.platform.PrefKeys
import com.mobiletel.incomingcall.platform.ScheduleStore
import com.mobiletel.incomingcall.ringer.RingerHub

/**
 * Module 2 + 4 — the foreground service that owns the call once the alarm fires.
 *
 * A service is used rather than an activity because the ringer has to survive
 * the activity being backgrounded or destroyed the moment HyperOS applies its
 * background-activity restrictions. The service holds the ringtone and the
 * vibration pattern, and posts either a full-screen intent (locked) or a
 * heads-up notification (unlocked), exactly as Module 2 specifies.
 */
class IncomingCallService : Service() {

    private var audioManager: AudioManager? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> handleStart(
                intent.getStringExtra(CallAlarmSchedulerV2.EXTRA_SCHEDULE_ID).orEmpty()
            )
            ACTION_STOP -> {
                Log.i(TAG, "Stop requested")
                teardown()
                return START_NOT_STICKY
            }
            ACTION_SILENCE -> {
                // Module 4: a volume key mutes the ringer; the call screen stays.
                Log.i(TAG, "Silenced by volume key")
                RingerHub.stop()
            }
            else -> Log.w(TAG, "Unknown action: ${intent?.action}")
        }
        return START_STICKY
    }

    private fun handleStart(scheduleId: String) {
        val call = CallPayloadResolver.resolve(this, scheduleId)
        val name = call.name
        val number = call.number

        // Move the payload into the active-call slot *before* removing the
        // schedule. The full-screen intent fired below re-reads the payload by
        // id (see LaunchSignalRelay), and deleting first left that second
        // reader with nothing — which is why every saved contact rang as
        // "Unknown" on the ring screen while the notification showed the name.
        if (scheduleId.isNotEmpty()) {
            ActiveCallStore.put(
                this,
                scheduleId,
                mapOf(
                    PrefKeys.NAME to call.name,
                    PrefKeys.NUMBER to call.number,
                    PrefKeys.SIM_LABEL to call.simLabel,
                    PrefKeys.VIBRATE to call.vibrate,
                    "scheduleId" to scheduleId,
                )
            )
            // Consumed: a reboot must not replay a call already ringing.
            ScheduleStore.remove(this, scheduleId)
        }

        val notification = buildNotification(name, number, scheduleId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Module 4/5: switch to the in-communication audio mode so the OS
        // treats the device as being on a call, then start the ringer.
        setVoiceMode(true)
        RingerHub.start(this, call.vibrate)

        val locked = isDeviceLocked()
        Log.i(TAG, "Call from $name <$number> (locked=$locked)")

        if (locked) {
            startActivity(fullScreenIntentIntent(name, number, scheduleId))
        }
        // When unlocked, the heads-up notification below is the presentation.
        // Posting it in both cases would stack two surfaces on the lock screen.
    }

    /**
     * The heads-up / lock-screen notification.
     *
     * [scheduleId] must be the real id, not an empty string: when the device is
     * unlocked the notification *is* the presentation, and tapping it opens the
     * same ring screen. An empty id there meant Dart had no way to identify the
     * call, so the screen fell back to "Unknown" on exactly the path the user
     * takes on an unlocked handset.
     */
    private fun buildNotification(name: String, number: String, scheduleId: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val fullScreen = PendingIntent.getActivity(
            this,
            REQUEST_FULL_SCREEN,
            fullScreenIntentIntent(name, number, scheduleId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return builder
            .setContentTitle(name.ifBlank { "Unknown" })
            .setContentText(number.ifBlank { "Incoming call" })
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setCategory(Notification.CATEGORY_CALL)
            .setPriority(Notification.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreen)
            .setFullScreenIntent(fullScreen, true)
            .build()
    }

    private fun fullScreenIntentIntent(name: String, number: String, scheduleId: String): Intent {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = MainActivityAction.SHOW_INCOMING_CALL
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(PrefKeys.NAME, name)
            putExtra(PrefKeys.NUMBER, number)
            putExtra(PrefKeys.LAUNCH_SOURCE, "alarm")
            putExtra(CallAlarmSchedulerV2.EXTRA_SCHEDULE_ID, scheduleId)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Required from Android 14: a full-screen intent is only used for
            // calls/alarms, so the use case has to be declared.
            intent.putExtra(
                "android.app.fullScreenIntentBehavior",
                "FULL_SCREEN_INTENT_ALLOW"
            )
        }
        return intent
    }

    private fun isDeviceLocked(): Boolean {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        return keyguard?.isKeyguardLocked ?: false
    }

    private fun setVoiceMode(enabled: Boolean) {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        runCatching {
            audioManager?.mode = if (enabled) {
                AudioManager.MODE_IN_COMMUNICATION
            } else {
                AudioManager.MODE_NORMAL
            }
        }.onFailure { Log.w(TAG, "Could not set audio mode: ${it.message}") }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Incoming call alerts and call screen."
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(false) // the ringer owns haptics, not the channel
        }
        manager.createNotificationChannel(channel)
    }

    private fun teardown() {
        RingerHub.stop()
        setVoiceMode(false)
        // The call is over: release the payload so a later call cannot be
        // resolved against this one's details.
        ActiveCallStore.clear(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        RingerHub.stop()
        setVoiceMode(false)
        ActiveCallStore.clear(this)
        super.onDestroy()
    }

    companion object {
        private const val TAG = "IncomingCallService"
        private const val CHANNEL_ID = "ic_incoming"
        private const val REQUEST_FULL_SCREEN = 9001
        private const val NOTIFICATION_ID = 9002
        const val ACTION_START = "com.mobiletel.incomingcall.action.START_CALL"
        const val ACTION_STOP = "com.mobiletel.incomingcall.action.STOP_CALL"
        const val ACTION_SILENCE = "com.mobiletel.incomingcall.action.SILENCE_RINGER"
    }
}
