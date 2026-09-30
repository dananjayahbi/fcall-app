package com.mobiletel.incomingcall.platform

import android.content.Context

/**
 * Resolves the caller's details when an alarm fires.
 *
 * ## Why this indirection exists
 *
 * Two storage shapes now coexist, deliberately:
 *
 *  * [ScheduleStore] — one entry per armed call, keyed by schedule id. This is
 *    the shape the multi-schedule feature needs.
 *  * [CallSessionStore] — the original single slot, still written by the
 *    quick-action path and still read by [com.mobiletel.incomingcall.MainActivity]
 *    before the Flutter engine exists.
 *
 * The service must not care which one fired, and it must not have to change
 * every time a new caller is added. Resolving here keeps the fallback logic in
 * one place, so a future third shape is a single new `when` branch rather than
 * an edit in the service, in the receiver and in the activity.
 *
 * A **missing** payload is not an error: it yields a fallback that still rings,
 * because a silent device is a worse failure than a call from "Unknown".
 */
object CallPayloadResolver {

    private const val FALLBACK_NAME = "Unknown"

    data class Resolved(
        val scheduleId: String,
        val name: String,
        val number: String,
        val simLabel: String,
        val vibrate: Boolean,
    )

    fun resolve(context: Context, scheduleId: String): Resolved {
        // Three stores, consulted in order of authority. The order is the whole
        // point of this class: the previous version checked only the first two,
        // so a call whose schedule row had already been consumed resolved to
        // "Unknown" on the ring screen while the notification showed the right
        // name — two readers, two different answers.
        //
        //  1. [ActiveCallStore] — the call currently being delivered. Highest
        //     authority: it is the payload the *service* is ringing from, so
        //     agreeing with it is what keeps the notification and the ring
        //     screen showing the same caller.
        //  2. [ScheduleStore] — the pending row for this id, still armed.
        //  3. [CallSessionStore] — the legacy single slot (quick action, and
        //     alarms armed by an older build).
        val active = ActiveCallStore.readPayload(context)
        val scheduled = if (scheduleId.isNotEmpty()) {
            ScheduleStore.readOne(context, scheduleId)
        } else {
            emptyMap()
        }
        val legacy = CallSessionStore.readPayload(context)

        val effective = when {
            active.isNotEmpty() && matches(active, scheduleId) -> active
            scheduled.isNotEmpty() -> scheduled
            active.isNotEmpty() -> active
            else -> legacy
        }

        return Resolved(
            scheduleId = scheduleId.ifEmpty { ActiveCallStore.scheduleId(context) },
            name = stringOr(effective, PrefKeys.NAME, FALLBACK_NAME),
            number = stringOr(effective, PrefKeys.NUMBER),
            simLabel = stringOr(effective, PrefKeys.SIM_LABEL, "SIM 1"),
            vibrate = boolOr(effective, PrefKeys.VIBRATE, true),
        )
    }

    /**
     * True when [payload] is the call identified by [scheduleId].
     *
     * A stale [ActiveCallStore] entry from a *previous* call must not be
     * preferred over the schedule that is actually firing — otherwise answering
     * one call and having another fire moments later would announce the first
     * caller twice.
     */
    private fun matches(payload: Map<String, Any?>, scheduleId: String): Boolean {
        if (scheduleId.isEmpty()) return true
        val storedId = payload["scheduleId"]?.toString().orEmpty()
        // A payload saved without an id cannot be proven wrong, so it is allowed
        // through rather than discarded.
        return storedId.isEmpty() || storedId == scheduleId
    }

    private fun stringOr(payload: Map<String, Any?>, key: String, fallback: String = ""): String {
        val value = payload[key]?.toString() ?: return fallback
        return value.ifBlank { fallback }
    }

    private fun boolOr(payload: Map<String, Any?>, key: String, fallback: Boolean): Boolean =
        when (val value = payload[key]) {
            is Boolean -> value
            is String -> value.toBoolean()
            else -> fallback
        }
}
