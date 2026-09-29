package com.mobiletel.incomingcall.ringer

import android.content.Context
import android.util.Log

/**
 * Process-wide owner of the single active [RingerController].
 *
 * ## Why this exists
 *
 * The ringer used to be constructed in two places: `IncomingCallService` (so
 * the ring survives the activity being killed) and `AndroidBridgeImpl` (so Dart
 * could start and stop it). Those are two `Ringtone` and two `Vibrator`
 * instances playing at once, and the failure is asymmetric and hard to read:
 * answering the call calls `stopRinger` on the *bridge's* controller only, so
 * the *service's* ringer keeps sounding. The user hears a ringtone that will
 * not stop until the call is ended — the most obviously broken behaviour a
 * call alert can have.
 *
 * Routing every entry point through one instance makes start/stop idempotent
 * across the service, the bridge and the volume-key path, which is the
 * behaviour Module 4/5 specifies.
 *
 * The application context is used deliberately: the ringer must outlive any
 * activity, so it cannot be scoped to one.
 */
object RingerHub {

    private const val TAG = "RingerHub"

    @Volatile
    private var controller: RingerController? = null

    /** Returns the shared controller, creating it on first use. */
    @Synchronized
    fun of(context: Context): RingerController {
        controller?.let { return it }
        val created = RingerController(context.applicationContext)
        controller = created
        return created
    }

    fun start(context: Context, vibrate: Boolean) {
        runCatching { of(context).start(vibrate) }
            .onFailure { Log.e(TAG, "start failed: ${it.message}") }
    }

    fun stop() {
        runCatching { controller?.stop() }
            .onFailure { Log.e(TAG, "stop failed: ${it.message}") }
    }

    fun preview(context: Context) {
        runCatching { of(context).preview() }
            .onFailure { Log.e(TAG, "preview failed: ${it.message}") }
    }

    /**
     * Drops the instance so a later call builds a fresh one.
     *
     * Only for teardown — a `Ringtone` whose `stop()` failed on an OEM build
     * would otherwise be handed to the next call and be un-stoppable.
     */
    @Synchronized
    fun release() {
        runCatching { controller?.stop() }
        controller = null
    }
}
