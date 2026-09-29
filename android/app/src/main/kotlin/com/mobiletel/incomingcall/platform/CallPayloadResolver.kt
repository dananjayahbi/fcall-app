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
        val payload = if (scheduleId.isNotEmpty()) {
            ScheduleStore.readOne(context, scheduleId)
        } else {
            emptyMap()
        }

        // Fall back to the legacy single slot when the id-addressed lookup came
        // back empty. This is the path a quick-action or an alarm armed by the
        // previous app version takes.
        val effective = if (payload.isEmpty()) CallSessionStore.readPayload(context) else payload

        return Resolved(
            scheduleId = scheduleId,
            name = stringOr(effective, PrefKeys.NAME, FALLBACK_NAME),
            number = stringOr(effective, PrefKeys.NUMBER),
            simLabel = stringOr(effective, PrefKeys.SIM_LABEL, "SIM 1"),
            vibrate = boolOr(effective, PrefKeys.VIBRATE, true),
        )
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
