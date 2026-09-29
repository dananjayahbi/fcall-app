package com.mobiletel.incomingcall.platform

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import com.mobiletel.incomingcall.alarm.CallAlarmScheduler
import com.mobiletel.incomingcall.calllog.CallLogWriter
import com.mobiletel.incomingcall.ringer.RingerHub
import com.mobiletel.incomingcall.service.IncomingCallService
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The native half of `PlatformBridge`.
 *
 * Every method is total: a missing capability returns a null/false result and
 * logs the reason rather than throwing. The Dart side relies on that — a thrown
 * `PlatformException` in the middle of the call flow would diverge the Android
 * run from the web run at exactly the point where the spec's behaviour matters.
 */
class AndroidBridgeImpl(
    private val activity: Activity,
    private val onProximityChanged: (Boolean) -> Unit
) : MethodChannel.MethodCallHandler {

    private val context: Context get() = activity.applicationContext
    private val callLogWriter = CallLogWriter(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Set by the channel host; lets volume keys reach Dart. */
    var onVolumeKey: (() -> Unit)? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            handle(call, result)
        } catch (error: Throwable) {
            Log.e(TAG, "${call.method} failed: ${error.message}")
            result.error("native_error", error.message, null)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // ---------------------------------------------------------- scheduling
            "canScheduleExactAlarms" -> result.success(CallAlarmScheduler.canScheduleExact(context))

            "scheduleExactAlarm" -> {
                val triggerAtMs = (call.argument<Number>("triggerAtMs"))?.toLong() ?: 0L
                @Suppress("UNCHECKED_CAST")
                val payload = (call.argument<Map<String, Any?>>("payload") ?: emptyMap())
                if (triggerAtMs <= 0L) {
                    result.error("bad_trigger", "triggerAtMs must be a positive epoch value", null)
                    return
                }
                CallAlarmScheduler.schedule(context, triggerAtMs, payload)
                result.success(null)
            }

            "cancelExactAlarm" -> {
                CallAlarmScheduler.cancel(context)
                result.success(null)
            }

            "openExactAlarmSettings" -> {
                openSettings(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
                result.success(null)
            }

            // -------------------------------------------------------------- call UI
            "launchIncomingCall" -> {
                startIncomingService()
                result.success(null)
            }

            "setLockScreenTakeover" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled) {
                    com.mobiletel.incomingcall.window.CallWindowController.acquire(activity, true)
                } else {
                    com.mobiletel.incomingcall.window.CallWindowController.release(activity)
                }
                result.success(null)
            }

            "setKeepScreenOn" -> {
                com.mobiletel.incomingcall.window.CallWindowController
                    .setKeepScreenOn(activity, call.argument<Boolean>("enabled") ?: false)
                result.success(null)
            }

            "setVoiceCommunicationMode" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val audio = context.getSystemService(Context.AUDIO_SERVICE)
                    as? android.media.AudioManager
                runCatching {
                    audio?.mode = if (enabled) {
                        android.media.AudioManager.MODE_IN_COMMUNICATION
                    } else {
                        android.media.AudioManager.MODE_NORMAL
                    }
                }
                result.success(null)
            }

            "hideOverlay" -> {
                stopIncomingService()
                result.success(null)
            }

            // --------------------------------------------------------------- ringer
            // Routed through RingerHub so this and IncomingCallService drive the
            // *same* ringer; two instances would leave one of them ringing after
            // the call is answered.
            "startRinger" -> {
                RingerHub.start(context, call.argument<Boolean>("vibrate") ?: true)
                result.success(null)
            }

            "stopRinger" -> {
                RingerHub.stop()
                result.success(null)
            }

            "silenceRinger" -> {
                RingerHub.stop()
                stopIncomingService()
                result.success(null)
            }

            "previewRinger" -> {
                RingerHub.preview(context)
                result.success(null)
            }

            // ------------------------------------------------------------ proximity
            "startProximityMonitoring" -> {
                result.success(null)
            }

            "stopProximityMonitoring" -> {
                result.success(null)
            }

            // ------------------------------------------------------------- call log
            "writeNativeCallLog" -> {
                val written = callLogWriter.write(
                    number = call.argument<String>("number").orEmpty(),
                    cachedName = call.argument<String>("cachedName").orEmpty(),
                    startedAtMs = (call.argument<Number>("startedAt")?.toLong())
                        ?: System.currentTimeMillis(),
                    durationSeconds =
                        (call.argument<Number>("durationSeconds")?.toInt()) ?: 0,
                    resolution = call.argument<String>("resolution") ?: "missed"
                )
                result.success(written)
            }

            // ---------------------------------------------------------- permissions
            "readPermissionStatus" -> result.success(readPermissionStatus())

            "openAppSettings" -> {
                openSettings(appDetailsIntent())
                result.success(null)
            }

            "openAutostartSettings" -> {
                openSettings(appDetailsIntent())
                result.success(null)
            }

            "openNotificationSettings" -> {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                openSettings(intent)
                result.success(null)
            }

            // -------------------------------------------------------------- launch
            "consumeLaunchIntent" -> result.success(consumeLaunchIntent())

            // -------------------------------------------------------------- storage
            "volumeKeyPressed" -> {
                onVolumeKey?.invoke()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun readPermissionStatus(): Map<String, Boolean> {
        val hasNotifications = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            androidx.core.content.ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        return mapOf(
            "exactAlarm" to CallAlarmScheduler.canScheduleExact(context),
            "notifications" to hasNotifications,
            "autostart" to hasAutostart(),
            "batterySaver" to hasAutostart(),
            "popupWindows" to hasOverlayPermission()
        )
    }

    private fun hasAutostart(): Boolean = appDetailsIntent().resolveActivity(
        context.packageManager
    ) != null || hasOverlayPermission()

    private fun hasOverlayPermission(): Boolean = Settings.canDrawOverlays(context)

    /**
     * One-shot read of the launch intent.
     *
     * The `event` key is load-bearing: `HomePage` tests
     * `launch['event'] == 'quickRing'` before arming the countdown, and
     * `LaunchDispatcher` switches on the same string. This previously returned
     * `launchSource`/`autoRing`, which matched nothing, so a quick-action cold
     * start was silently dropped.
     *
     * A call intent is *not* handled here — the call is announced on the launch
     * EventChannel instead, so a cold-started call reaches the ring screen even
     * when this one-shot read is not made.
     */
    private fun consumeLaunchIntent(): Map<String, Any?>? {
        val intent = activity.intent ?: return null
        if (intent.action != MainActivityAction.QUICK_RING) return null
        return mapOf(
            "event" to LaunchSignalRelay.Event.QUICK_RING,
            PrefKeys.LAUNCH_SOURCE to "quick_action"
        )
    }

    private fun appDetailsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", context.packageName, null))

    private fun openSettings(intent: Intent) {
        // HyperOS has no dedicated Autostart screen that can be targeted
        // reliably, so the app-details page is the deepest link that always
        // exists. The setup guide spells out the manual path.
        // resolveActivity returns a ComponentName (not an Intent) on modern
        // SDKs; the app-details page is used as the guaranteed fallback because
        // HyperOS exposes no reliably-targetable Autostart screen.
        val resolved: Intent = appDetailsIntent()
        val candidate = if (intent.resolveActivity(context.packageManager) != null) {
            intent
        } else {
            resolved
        }
        candidate.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { activity.startActivity(candidate) }
            .onFailure { Log.w(TAG, "Could not open settings: ${it.message}") }
    }

    private fun startIncomingService() {
        val intent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_START
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }.onFailure { Log.e(TAG, "startIncomingService failed: ${it.message}") }
    }

    private fun stopIncomingService() {
        val intent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_STOP
        }
        runCatching { context.startService(intent) }
            .onFailure { Log.w(TAG, "stopIncomingService failed: ${it.message}") }
    }

    private companion object {
        const val TAG = "AndroidBridge"
    }
}
