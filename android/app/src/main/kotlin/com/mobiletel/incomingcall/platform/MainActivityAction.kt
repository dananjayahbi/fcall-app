package com.mobiletel.incomingcall.platform

/**
 * The launch actions `MainActivity` answers to.
 *
 * Declared here rather than on `MainActivity` itself so that
 * [LaunchSignalRelay] — which lives in `platform` — can read them without
 * depending on the activity package. `MainActivity` references these instead of
 * redeclaring the strings, so a rename is a one-line change and the two halves
 * cannot drift.
 */
object MainActivityAction {

    /** A call is arriving: posted as the full-screen intent by `IncomingCallService`. */
    const val SHOW_INCOMING_CALL = "com.mobiletel.incomingcall.action.SHOW_INCOMING_CALL"

    /** The launcher shortcut / quick tile: arm a short countdown. */
    const val QUICK_RING = "com.mobiletel.incomingcall.action.QUICK_RING"
}
