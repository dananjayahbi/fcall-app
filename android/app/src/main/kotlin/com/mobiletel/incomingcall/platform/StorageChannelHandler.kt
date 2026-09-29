package com.mobiletel.incomingcall.platform

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `SharedPreferences` access for the Dart data layer.
 *
 * Small enough to keep separate from [AndroidBridgeImpl] — the bridge is about
 * hardware, this is about persistence, and merging them would put two unrelated
 * concerns behind one channel name.
 */
class StorageChannelHandler(context: Context) : MethodChannel.MethodCallHandler {

    private val prefs = context.applicationContext
        .getSharedPreferences("ic_storage", Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readAll" -> result.success(
                prefs.all.entries.associate { (key, value) -> key to value.toString() }
            )

            "write" -> {
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key == null || value == null) {
                    result.error("bad_args", "key and value are required", null)
                    return
                }
                prefs.edit().putString(key, value).apply()
                result.success(null)
            }

            "delete" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("bad_args", "key is required", null)
                    return
                }
                prefs.edit().remove(key).apply()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
