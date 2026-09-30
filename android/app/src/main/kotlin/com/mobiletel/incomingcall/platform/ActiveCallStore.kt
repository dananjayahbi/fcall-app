package com.mobiletel.incomingcall.platform

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Holds the payload of the call that is **currently being delivered**.
 *
 * ## Why the schedule row is not enough
 *
 * The service consumes a schedule as soon as its alarm fires — that row is
 * deleted so a reboot cannot replay a call the user already handled. But the
 * full-screen intent that draws the ring screen is fired *after* that deletion,
 * and [LaunchSignalRelay] re-reads the payload by schedule id. Finding nothing,
 * it fell back to the legacy single slot, which is empty for a multi-schedule
 * call, and the ring screen showed **"Unknown"** for every contact the user had
 * saved a name for.
 *
 * This store closes that gap: the payload is moved from the pending list into
 * this single slot at delivery time, so the second reader still finds it. It
 * is cleared when the call ends, so it can hold exactly one call by design.
 */
object ActiveCallStore {

    private const val PREFS = "ic_active_call"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_SCHEDULE_ID = "scheduleId"

    /**
     * Records the delivered call.
     *
     * The schedule id is kept alongside the payload so the relay can still
     * identify which call it is announcing, even after the pending row is gone.
     */
    fun put(context: Context, scheduleId: String, payload: Map<String, Any?>) {
        val json = JSONObject()
        payload.forEach { (key, value) -> if (value != null) json.put(key, value) }
        prefs(context).edit()
            .putString(KEY_PAYLOAD, json.toString())
            .putString(KEY_SCHEDULE_ID, scheduleId)
            .apply()
    }

    fun readPayload(context: Context): Map<String, Any?> {
        val raw = prefs(context).getString(KEY_PAYLOAD, null) ?: return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            val result = HashMap<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                if (!json.isNull(key)) result[key] = json.get(key)
            }
            result
        }.getOrElse { emptyMap() }
    }

    fun scheduleId(context: Context): String =
        prefs(context).getString(KEY_SCHEDULE_ID, null).orEmpty()

    fun isEmpty(context: Context): Boolean = readPayload(context).isEmpty()

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_PAYLOAD)
            .remove(KEY_SCHEDULE_ID)
            .apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
