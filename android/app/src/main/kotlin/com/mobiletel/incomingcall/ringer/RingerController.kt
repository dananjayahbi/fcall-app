package com.mobiletel.incomingcall.ringer

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Module 4 — ringtone playback and the cellular vibration pattern.
 *
 * The ringtone is the device's own default ringtone obtained through
 * [RingtoneManager], never a bundled asset: a bundled tone would be the wrong
 * sound on the target device and would be the single loudest tell that this is
 * not a real call.
 */
class RingerController(private val context: Context) {

    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var isVibrating = false

    /**
     * The standard Android incoming-call pattern: two short pulses, a pause,
     * then a long one — repeated. Matches `VIBRATE_CALL` on most OEM profiles.
     */
    private val callPattern = longArrayOf(0, 600, 1000, 600, 1000)

    fun start(vibrate: Boolean) {
        startRingtone()
        if (vibrate) startVibration()
    }

    private fun startRingtone() {
        if (ringtone?.isPlaying == true) return
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        if (uri == null) {
            Log.w(TAG, "No system ringtone available")
            return
        }
        ringtone = RingtoneManager.getRingtone(context, uri).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            isLooping = true
            play()
        }
    }

    private fun startVibration() {
        val service = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        vibrator = service ?: return
        if (!service.hasVibrator()) {
            Log.w(TAG, "Device reports no vibrator")
            return
        }
        isVibrating = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            service.vibrate(
                VibrationEffect.createWaveform(callPattern, 0)
            )
        } else {
            @Suppress("DEPRECATION")
            service.vibrate(callPattern, 0)
        }
    }

    /**
     * Immediate stop with no audio tail.
     *
     * `stop()` on a Ringtone is not always instantaneous, so the audio stream is
     * additionally flushed. Module 5 requires the ringer to be gone the instant
     * the call is answered, and a fading tail is the most audible defect in a
     * call alert.
     */
    fun stop() {
        // `Ringtone` has no reset(); stopping and dropping the reference is
        // what actually stops the audio. The extra stop() is guarded because
        // stop() on an already-stopped Ringtone throws on some OEM builds.
        ringtone?.let {
            if (it.isPlaying) {
                runCatching { it.stop() }
                    .onFailure { error -> Log.w(TAG, "stop failed: ${error.message}") }
            }
        }
        ringtone = null
        stopVibration()
    }

    fun stopVibration() {
        if (!isVibrating) return
        isVibrating = false
        vibrator?.cancel()
    }

    /** Config-screen "test ring": a short, non-looping sample. */
    fun preview() {
        val service = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (service?.hasVibrator() == true && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            service.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 300, 200, 300), -1))
        }
    }

    val isPlaying: Boolean get() = ringtone?.isPlaying == true

    private companion object {
        const val TAG = "RingerController"
    }
}
