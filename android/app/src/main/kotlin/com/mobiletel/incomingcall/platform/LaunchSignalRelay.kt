package com.mobiletel.incomingcall.platform

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Module 2/3 — the native → Dart "a call is arriving" signal.
 *
 * ## Why this exists
 *
 * The alarm fires with **no Dart VM alive**: HyperOS killed the process hours
 * ago. `IncomingCallService` posts a full-screen intent which cold-starts
 * `MainActivity`, but on its own that only brings up the Flutter view — it does
 * not tell Dart a call is in progress, so `CallFlowHost` stays on `HomePage`
 * and no ring screen is ever shown. The call becomes audible with no visible
 * UI, which is exactly the "it rang but nothing appeared" symptom.
 *
 * The Dart side already listens on the `…/launch` EventChannel and routes
 * `callIncoming` into `CallOrchestrator.beginRinging`; that channel simply had
 * no native registration. This class is the missing producer.
 *
 * ## Why the buffer is mandatory
 *
 * `MainActivity.onCreate` runs *before* Dart subscribes to the channel, so a
 * sink is normally `null` at the moment the call lands. Emitting then would
 * silently drop the only event in the call. The event is therefore parked in
 * [pending] and flushed on the first `onListen` — which is what makes the
 * cold-start case work at all.
 */
object LaunchSignalRelay {

    private const val TAG = "LaunchSignalRelay"

    /** Event names shared with `LaunchDispatcher` in `lib/services/launch_dispatcher.dart`. */
    object Event {
        const val CALL_INCOMING = "callIncoming"
        const val QUICK_RING = "quickRing"
    }

    private var sink: EventChannel.EventSink? = null
    private var pending: Map<String, Any?>? = null

    /**
     * The application context, set once by `MainActivity`.
     *
     * An `object` has no `Context`, and the relay must be able to read the
     * stored payload without one being threaded in from every call site. The
     * application context is the correct choice — the payload is process-wide
     * and must outlive any activity.
     */
    @Volatile
    var appContext: Context? = null
        internal set

    /** Hands the channel a sink and flushes anything that arrived before Dart was ready. */
    fun attach(newSink: EventChannel.EventSink?) {
        sink = newSink
        val parked = pending ?: return
        pending = null
        Log.i(TAG, "Flushing the parked $parked")
        runCatching { newSink?.success(parked) }
            .onFailure { Log.e(TAG, "flush failed: ${it.message}") }
    }

    fun detach() {
        sink = null
    }

    /**
     * Emits [event], or parks it until Dart is listening.
     *
     * Never throws: a failure here must not take down the call pipeline that
     * is already ringing natively.
     */
    fun emit(event: String, payload: Map<String, Any?> = emptyMap()) {
        val message = HashMap<String, Any?>(payload)
        message["event"] = event
        val active = sink
        if (active == null) {
            pending = message
            Log.i(TAG, "No sink yet; parked '$event' for Dart")
            return
        }
        runCatching { active.success(message) }
            .onFailure {
                Log.e(TAG, "emit '$event' failed: ${it.message}")
                pending = message
            }
    }

    /**
     * Translates a `MainActivity` launch intent into a launch signal.
     *
     * Called from both `onCreate` and `onNewIntent`; a call arriving while the
     * app is already foregrounded arrives through `onNewIntent`, and without it
     * that second case would never reach Dart.
     */
    fun handleActivityIntent(intent: Intent?) {
        when (intent?.action) {
            MainActivityAction.SHOW_INCOMING_CALL -> {
                // Resolve through the same path the service used, so Dart is told
                // the identical caller. Reading the single legacy slot here would
                // show one name while the service rings another.
                val scheduleId =
                    intent.getStringExtra(
                        com.mobiletel.incomingcall.alarm.CallAlarmSchedulerV2.EXTRA_SCHEDULE_ID
                    ).orEmpty()
                val call = appContext?.let { CallPayloadResolver.resolve(it, scheduleId) }
                    ?: CallPayloadResolver.Resolved(
                        scheduleId = scheduleId,
                        name = "Unknown",
                        number = "",
                        simLabel = "SIM 1",
                        vibrate = true,
                    )
                emit(
                    Event.CALL_INCOMING,
                    mapOf(
                        PrefKeys.NAME to call.name,
                        PrefKeys.NUMBER to call.number,
                        PrefKeys.SIM_LABEL to call.simLabel,
                        PrefKeys.VIBRATE to call.vibrate,
                        PrefKeys.LAUNCH_SOURCE to "alarm",
                        "scheduleId" to scheduleId,
                    )
                )
            }

            MainActivityAction.QUICK_RING -> emit(Event.QUICK_RING)
        }
    }
}
