package com.mobiletel.incomingcall.window

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * Module 3 — the lock-screen takeover.
 *
 * Modern Android needs four separate things to happen, and missing any one of
 * them produces the same symptom ("the call screen never appeared"):
 *
 *  1. `FLAG_SHOW_WHEN_LOCKED`  — draw while the keyguard is up
 *  2. `FLAG_TURN_SCREEN_ON`    — wake the panel
 *  3. `FLAG_DISMISS_KEYGUARD`  — unlock a non-secure keyguard
 *  4. `setShowWhenLocked(true)` on the Activity itself (API 27+)
 *
 * `FLAG_DISMISS_KEYGUARD` deliberately does not clear a secure (PIN/biometric)
 * keyguard — the platform refuses to, and attempting it is what triggers the
 * "unlock to continue" lockout on Xiaomi devices. The call screen is shown
 * *over* the keyguard instead, which is the correct behaviour anyway.
 */
object CallWindowController {

    fun acquire(activity: Activity, keepScreenOn: Boolean) {
        val window = activity.window
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE)
                as? KeyguardManager
            if (keyguard != null && !keyguard.isKeyguardSecure) {
                keyguard.requestDismissKeyguard(activity, null)
            }
        }

        applyImmersiveMode(activity)
        if (keepScreenOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    fun release(activity: Activity) {
        val window = activity.window
        window.clearFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(false)
            activity.setTurnScreenOn(false)
        }
    }

    fun setKeepScreenOn(activity: Activity, enabled: Boolean) {
        if (enabled) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    /**
     * Full immersion: the call UI has no status bar, no navigation bar and no
     * system gesture inset, matching a real dialer takeover.
     */
    fun applyImmersiveMode(activity: Activity) {
        WindowCompat.setDecorFitsSystemWindows(activity.window, false)
        val controller = WindowInsetsControllerCompat(activity.window, activity.window.decorView)
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller.hide(WindowInsetsCompat.Type.systemBars())
    }

    fun restoreSystemBars(activity: Activity) {
        WindowCompat.setDecorFitsSystemWindows(activity.window, true)
        val controller = WindowInsetsControllerCompat(activity.window, activity.window.decorView)
        controller.show(WindowInsetsCompat.Type.systemBars())
    }
}
