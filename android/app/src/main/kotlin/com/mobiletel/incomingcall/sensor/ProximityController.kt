package com.mobiletel.incomingcall.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.PowerManager
import android.util.Log

/**
 * Module 5 — proximity-driven display control.
 *
 * Spec §5 is explicit that the correct mechanism is the hardware
 * `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, not a black overlay drawn in software. That is not
 * a stylistic preference: the wake lock is what makes the display **physically**
 * dark, so a camera pointed at the phone sees nothing and the panel stops
 * drawing power.
 *
 * The lock is created with a `PROXIMITY_SCREEN_OFF_WAKE_LOCK` level, which the
 * system itself scopes to the proximity sensor and releases on the FAR reading.
 * Holding it with no timeout and releasing it explicitly on FAR / [stop] keeps
 * the behaviour deterministic even if a reading is missed.
 */
class ProximityController(
    context: Context,
    private val onNearChanged: (Boolean) -> Unit
) : SensorEventListener {

    private val appContext = context.applicationContext
    private val sensorManager =
        appContext.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
    private val powerManager =
        appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager

    private var wakeLock: PowerManager.WakeLock? = null
    private var isNear = false
    private var isMonitoring = false

    fun start() {
        if (isMonitoring) return
        val manager = sensorManager ?: run {
            Log.w(TAG, "No SensorManager on this device")
            return
        }
        val sensor = manager.getDefaultSensor(Sensor.TYPE_PROXIMITY)
        if (sensor == null) {
            Log.w(TAG, "Device has no proximity sensor; screen lock disabled")
            return
        }
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        isMonitoring = true
        Log.i(TAG, "Proximity monitoring started")
    }

    fun stop() {
        if (!isMonitoring) return
        sensorManager?.unregisterListener(this)
        isMonitoring = false
        releaseWakeLock()
        isNear = false
        Log.i(TAG, "Proximity monitoring stopped")
    }

    override fun onSensorChanged(event: SensorEvent) {
        val distance = event.values.firstOrNull() ?: return
        // Binary sensors report either `near` (0) or `far` (maxRange); a short
        // threshold also handles tri-state sensors that report an intermediate
        // value when a cheek is a few millimetres away.
        val near = distance < event.sensor.maximumRange
        if (near == isNear) return
        isNear = near
        if (near) acquireWakeLock() else releaseWakeLock()
        onNearChanged(near)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = powerManager ?: return
        wakeLock = pm.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "ic:proximity"
        ).apply {
            // No timeout: released by the FAR reading or by [stop]. A
            // self-expiring lock would blank the screen mid-call on a sensor
            // glitch.
            acquire()
        }
        Log.i(TAG, "Proximity wake lock acquired")
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
            Log.i(TAG, "Proximity wake lock released")
        }
        wakeLock = null
    }

    private companion object {
        const val TAG = "ProximityController"
    }
}
