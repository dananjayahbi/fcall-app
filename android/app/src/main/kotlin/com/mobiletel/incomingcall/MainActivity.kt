package com.mobiletel.incomingcall

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import com.mobiletel.incomingcall.platform.AndroidBridgeImpl
import com.mobiletel.incomingcall.platform.CallSessionStore
import com.mobiletel.incomingcall.platform.MainActivityAction
import com.mobiletel.incomingcall.platform.PrefKeys
import com.mobiletel.incomingcall.platform.StorageChannelHandler
import com.mobiletel.incomingcall.sensor.ProximityController
import com.mobiletel.incomingcall.window.CallWindowController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var bridge: AndroidBridgeImpl? = null
    private var proximity: ProximityController? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        proximity = ProximityController(this) { near ->
            // Runs on the sensor thread; hop to main before crossing the channel.
            runOnUiThread { eventSink?.success(near) }
        }

        val implementation = AndroidBridgeImpl(this) { onVolumeKeyPressed() }
        bridge = implementation

        MethodChannel(messenger, CHANNEL_BRIDGE).setMethodCallHandler(implementation)
        MethodChannel(messenger, CHANNEL_STORAGE)
            .setMethodCallHandler(StorageChannelHandler(this))
        EventChannel(messenger, CHANNEL_PROXIMITY)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                    proximity?.start()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /**
     * Module 4 — intercept the physical volume keys.
     *
     * This **cannot** be done in Dart. When the activity sits behind the keyguard
     * the Flutter view does not receive key events at all, so the ringer would
     * keep sounding after the user presses Volume Down — the single most
     * obviously wrong behaviour for a call alert. The event is forwarded over
     * the channel instead.
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            onVolumeKeyPressed()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun onVolumeKeyPressed() {
        bridge?.let { impl ->
            val messenger = flutterEngine?.dartExecutor?.binaryMessenger
            if (messenger != null) {
                runOnUiThread {
                    MethodChannel(messenger, CHANNEL_BRIDGE)
                        .invokeMethod("volumeKeyPressed", null)
                }
            }
            // Also silence natively so the ringer stops even if Dart is not
            // running yet — a delay here is the difference between the device
            // feeling real and feeling broken.
            impl.onMethodCall(
                io.flutter.plugin.common.MethodCall("silenceRinger", null),
                object : MethodChannel.Result {
                    override fun success(result: Any?) = Unit
                    override fun error(code: String, message: String?, details: Any?) = Unit
                    override fun notImplemented() = Unit
                }
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
    }

    /**
     * Module 2/3: the activity may be launched cold by the full-screen intent or
     * by the quick-action tile, with no Dart VM running yet. The stored payload
     * is read here so the Dart side can rebuild the identical call screen.
     */
    private fun handleLaunchIntent(intent: Intent?) {
        val action = intent?.action
        if (action == MainActivityAction.QUICK_RING) {
            CallWindowController.applyImmersiveMode(this)
            return
        }
        if (action == ACTION_SHOW_INCOMING_CALL) {
            val payload = CallSessionStore.readPayload(this)
            if (payload.isNotEmpty()) {
                CallWindowController.acquire(this, keepScreenOn = true)
            }
        }
    }

    override fun onDestroy() {
        proximity?.stop()
        // Never leave a proximity wake lock held by a destroyed activity.
        if (isFinishing) {
            CallWindowController.restoreSystemBars(this)
        }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_BRIDGE = "com.mobiletel.incomingcall/bridge"
        private const val CHANNEL_PROXIMITY = "com.mobiletel.incomingcall/proximity"
        private const val CHANNEL_STORAGE = "com.mobiletel.incomingcall/storage"
        const val ACTION_SHOW_INCOMING_CALL =
            "com.mobiletel.incomingcall.action.SHOW_INCOMING_CALL"
    }
}
