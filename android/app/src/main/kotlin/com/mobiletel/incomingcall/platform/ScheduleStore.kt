package com.mobiletel.incomingcall.platform

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persistent store for *many* armed calls.
 *
 * ## Why this replaces the single-slot [CallSessionStore]
 *
 * [CallSessionStore] kept one payload and one fire time, which cannot express
 * more than one pending call: arming a second overwrote the first, and its
 * [CallAlarmScheduler] used a hard-coded request code, so every alarm resolved
 * to the same [PendingIntent] and the last registration silently replaced all
 * previous ones. Two calls could not coexist at all.
 *
 * ## Shape
///
/// One JSON array under a single key. The whole list is small (a user schedules
/// a handful, not thousands), it is always read in full, and it must be written
/// atomically — a per-key scheme would let a crash between two writes leave a
/// schedule with no payload, which is the exact failure the whole feature
/// exists to prevent.
 */
object ScheduleStore {

    private const val PREFS = "ic_schedules"
    private const val KEY_LIST = "schedules"

    /** Each armed call is saved as one map. */
    fun save(context: Context, entry: Map<String, Any?>) {
        val id = entry["id"]?.toString().orEmpty()
        if (id.isEmpty()) return
        val current = readAll(context).toMutableList()
        val index = current.indexOfFirst { it["id"]?.toString() == id }
        val payload = JSONObject()
        entry.forEach { (key, value) -> if (value != null) payload.put(key, value) }
        if (index >= 0) {
            current[index] = payload
        } else {
            current.add(payload)
        }
        write(context, current)
    }

    fun delete(context: Context, id: String) {
        val current = readAll(context).toMutableList()
        current.removeAll { it.optString("id") == id }
        write(context, current)
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_LIST).apply()
    }

    fun readAll(context: Context): List<JSONObject> {
        val raw = prefs(context).getString(KEY_LIST, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            val result = ArrayList<JSONObject>(array.length())
            for (i in 0 until array.length()) {
                array.optJSONObject(i)?.let(result::add)
            }
            result
        }.getOrElse { emptyList() }
    }

    /** Looks up one armed call by id — used when its alarm fires. */
    fun readOne(context: Context, id: String): Map<String, Any?> {
        val found = readAll(context).firstOrNull { it.optString("id") == id }
            ?: return emptyMap()
        return toMap(found)
    }

    /** Removes the fired schedule so a delivered call is not re-delivered. */
    fun remove(context: Context, id: String) = delete(context, id)

    fun count(context: Context): Int = readAll(context).size

    private fun write(context: Context, items: List<JSONObject>) {
        val array = JSONArray()
        items.forEach(array::put)
        prefs(context).edit().putString(KEY_LIST, array.toString()).apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun toMap(json: JSONObject): Map<String, Any?> {
        val result = HashMap<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            if (!json.isNull(key)) result[key] = json.get(key)
        }
        return result
    }
}
