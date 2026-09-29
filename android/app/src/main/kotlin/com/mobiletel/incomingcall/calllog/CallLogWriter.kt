package com.mobiletel.incomingcall.calllog

import android.Manifest
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CallLog
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Module 6 / Phase 5.1 — writes a finished call into Android's native call
 * history so it appears in the Xiaomi Phone app alongside real calls.
 *
 * Column semantics that matter and are easy to get wrong:
 *
 *  * `TYPE` is `INCOMING` (1) for **all three** outcomes. A declined or missed
 *    incoming call is still an incoming call; the outcome is carried by
 *    `MISSED_REASON` (1 = missed, 2 = rejected, 0 = answered). Writing
 *    `TYPE_MISSED` instead makes a declined call look like a missed outbound
 *    one in the dialer.
 *  * `DURATION` is only meaningful for an answered call. A non-answered call
 *    records `0`, not the ring time.
 *  * `NEW` is `0` so the row is not rendered as unread.
 *
 * The numeric constants are literals rather than `CallLog.Calls` references
 * because the `MISSED_REASON_*` set is not uniformly public across API levels;
 * literals are stable, and each is annotated with its meaning.
 */
class CallLogWriter(private val context: Context) {

    private val resolver: ContentResolver get() = context.contentResolver

    fun hasPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALL_LOG) ==
            PackageManager.PERMISSION_GRANTED

    /** @return true when the row was accepted by the provider. */
    fun write(
        number: String,
        cachedName: String,
        startedAtMs: Long,
        durationSeconds: Int,
        resolution: String
    ): Boolean {
        if (!hasPermission()) {
            Log.w(TAG, "WRITE_CALL_LOG not granted; skipping native write")
            return false
        }
        if (number.isBlank()) {
            Log.w(TAG, "Refusing to write a call-log row with no number")
            return false
        }

        val values = ContentValues().apply {
            put(CallLog.Calls.CACHED_NAME, cachedName.ifBlank { null })
            put(CallLog.Calls.NUMBER, number)
            put(CallLog.Calls.TYPE, TYPE_INCOMING)
            put(CallLog.Calls.DATE, startedAtMs)
            put(
                CallLog.Calls.DURATION,
                if (resolution == RESOLUTION_ANSWERED) durationSeconds.toLong() else 0L
            )
            put(CallLog.Calls.NEW, 0)
            put(CallLog.Calls.MISSED_REASON, missedReasonFor(resolution))
        }

        return runCatching {
            val uri = resolver.insert(CallLog.Calls.CONTENT_URI, values)
            if (uri == null) {
                Log.w(TAG, "CallLog provider rejected the insert")
                false
            } else {
                Log.i(TAG, "Call-log row written: $uri")
                true
            }
        }.getOrElse { error ->
            Log.e(TAG, "Call-log insert failed: ${error.message}")
            false
        }
    }

    private fun missedReasonFor(resolution: String): Int = when (resolution) {
        RESOLUTION_ANSWERED -> MISSED_REASON_NOT_MISSED
        RESOLUTION_MISSED -> MISSED_REASON_MISSED
        RESOLUTION_DECLINED -> MISSED_REASON_REJECTED
        else -> MISSED_REASON_NOT_MISSED
    }

    companion object {
        private const val TAG = "CallLogWriter"

        /** `CallLog.Calls.TYPE_INCOMING` */
        const val TYPE_INCOMING = 1

        /** `MISSED_REASON_NOT_MISSED` — an answered incoming call. */
        const val MISSED_REASON_NOT_MISSED = 0

        /** `MISSED_REASON_MISSED` — the callee did not answer. */
        const val MISSED_REASON_MISSED = 1

        /** "Rejected by the callee" — declined by the user. */
        const val MISSED_REASON_REJECTED = 2

        const val RESOLUTION_ANSWERED = "answered"
        const val RESOLUTION_MISSED = "missed"
        const val RESOLUTION_DECLINED = "declined"
    }
}
