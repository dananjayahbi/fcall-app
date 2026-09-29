package com.mobiletel.incomingcall.platform

import android.content.Context
import org.json.JSONObject

/**
 * The bridge between the Dart layer and the native alarm/service pipeline.
 *
 * When an alarm fires there is no Dart VM alive yet — the process was killed by
 * HyperOS hours ago. The payload the Dart side registered has to be readable
 * from a BroadcastReceiver, so it is mirrored into SharedPreferences here the
 * moment the alarm is armed, and cleared when the call ends.
 */
object CallSessionStore {

    private const val PREFS = "ic_session"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_FIRE_AT = "fire_at"

    fun save(context: Context, payload: Map<String, Any?>, fireAtMs: Long) {
        val json = JSONObject()
        payload.forEach { (key, value) ->
            // Nulls are dropped rather than written as JSONObject.NULL: the
            // native readers all use CallSessionStore.stringOf/boolOf, which
            // treat a missing key and an explicit null identically.
            if (value != null) json.put(key, value)
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PAYLOAD, json.toString())
            .putLong(KEY_FIRE_AT, fireAtMs)
            .apply()
    }

    fun readPayload(context: Context): Map<String, Any?> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_PAYLOAD, null) ?: return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            val result = HashMap<String, Any?>()
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                if (!json.isNull(key)) {
                    result[key] = json.get(key)
                }
            }
            result
        }.getOrElse { emptyMap() }
    }

    fun fireAt(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_FIRE_AT, 0L)

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_PAYLOAD)
            .remove(KEY_FIRE_AT)
            .apply()
    }

    fun stringOf(payload: Map<String, Any?>, key: String, fallback: String = ""): String =
        payload[key]?.toString() ?: fallback

    fun boolOf(payload: Map<String, Any?>, key: String, fallback: Boolean = false): Boolean =
        when (val value = payload[key]) {
            is Boolean -> value
            is String -> value.toBoolean()
            else -> fallback
        }
}
