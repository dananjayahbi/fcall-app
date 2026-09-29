package com.mobiletel.incomingcall.platform

/**
 * Keys the Dart and native layers agree on.
 *
 * Declared on both sides: `lib/services/platform/platform_bridge.dart`
 * (`CallPayloadKeys`) and here. They are duplicated deliberately — a shared
 * constant library would couple the two builds for the sake of five strings,
 * and the duplication is documented on both sides so a rename is a two-line
 * change rather than a mystery.
 */
object PrefKeys {
    const val SESSION_ID = "sessionId"
    const val NAME = "name"
    const val NUMBER = "number"
    const val SIM_LABEL = "simLabel"
    const val VIBRATE = "vibrate"
    const val RINGER_SILENT = "ringerSilent"
    const val LAUNCH_SOURCE = "launchSource"

    /** Absolute fire time, persisted per schedule so a reboot can re-arm it. */
    const val FIRE_AT = "fireAt"

    /** Extras key used to hand the payload to the service. */
    const val EXTRA_PAYLOAD = "com.mobiletel.incomingcall.PAYLOAD"
}
