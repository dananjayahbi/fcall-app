# Verification Report

Target: Xiaomi Redmi 14C (Android 14 / HyperOS) · Date: 2026-09-29
Build under test: `incoming_call` (package `com.mobiletel.incomingcall`) @ `main` · Flutter 3.35.6 / Dart 3.9.2

---

## 0. Read this first — what was and was not verified

This app has a hard split between *logic/UI* (Dart, platform-independent) and
*hardware* (Kotlin, Android-only). Only the first half could be executed, because
**no physical Android device was attached during this session**. `flutter
devices` reported only Chrome and Edge.

| Layer | How it was verified | Status |
|---|---|---|
| Dart logic, state machine, all screens | 19 automated tests + live browser walkthrough | **Verified** |
| Kotlin native layer | Compiles and packages into a debug APK | **Compiles — not executed** |
| Device hardware behaviour (spec §7) | *not possible without the handset* | **NOT VERIFIED** |

The most important line in this report is the last one. Everything in spec §7
depends on an Android display, a keyguard, a proximity sensor and a system
content provider. **None of that has been run.** Claiming otherwise would be
exactly the kind of self-consistent-but-wrong result this project is designed to
avoid, so the Setup page ships with all five items deliberately un-ticked and the
app carries a `Web simulation` badge on every screen.

---

## 1. Build verification

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** (0 errors, 0 warnings, 0 info) |
| `flutter test` | **22/22 passed** |
| `flutter build web --release` | **Succeeded** — `build/web` |
| `flutter build apk --debug` | **Succeeded** — `build/app/outputs/flutter-apk/app-debug.apk` |

The APK build is the evidence that the native layer is real and syntactically
valid: all 11 Kotlin files compile under the Android Gradle Plugin, the manifest
merges (all 17 permissions, 3 receivers, 1 foreground service), and the DEX is
produced. It is **not** evidence that the alarm fires or the sensor works.

---

## 2. Automated test results

### 2.1 `test/call_flow_test.dart` — 14 tests

Uses a recording `FakeBridge` that captures the **ordered** sequence of hardware
calls. Ordering is what matters here: a state-only assertion passes even if the
ringer stops *after* proximity engages, which leaves an audible blip on answer.

| # | Test | What it pins |
|---|---|---|
| 1 | future trigger registers an exact alarm | Module 2 happy path |
| 2 | past trigger refused **before** touching the platform | an alarm registered in the past fires instantly — a surprise call |
| 3 | missing exact-alarm permission surfaces a reason | a silent failure here looks like "the app doesn't work" |
| 4 | arming persists the profile | the quick trigger reuses the stored number, not an empty one |
| 5 | takeover applied **before** ringer starts | otherwise the user hears a phone ring with a dark screen |
| 6 | volume key silences but keeps the call ringing | Module 4 contract |
| 7 | second volume key does **not** resume | a toggle is the giveaway; a real handset mutes once |
| 8 | ringer stops **before** proximity engages | Module 5 "terminates instantly" |
| 9 | proximity NEAR/FAR surfaced, teardown restarts cleanly | Module 5 state |
| 10 | hang-up releases every resource exactly once | no orphaned wake lock |
| 11 | second hang-up is a no-op | prevents a duplicate call-log row |
| 12 | answered call records the real duration | Module 6 |
| 13 | declined call records `0` duration, not ring time | ring time as duration renders as a 1-minute conversation |
| 14 | logging disabled → no write at all | the opt-out is real |

### 2.2 `test/widget_test.dart` — 8 tests

| # | Test | What it pins |
|---|---|---|
| 1 | home shown while phase is idle | the phase→screen mapping |
| 2 | ringing swaps in the incoming-call screen | Module 4 renders |
| 3 | tapping Answer replaces it with the active screen | the full ringing→active transition through a real tap |
| 4 | declining returns home and logs `declined` | Module 6 outcome routing |
| 5 | app bar carries the neutral name | "Fake Call" in the launcher gives it away instantly |
| 6-8 | no internal terminology rendered | four screens asserted free of *simulat / fake / preview / stub / headless / web / test* |

---

## 3. Live browser walkthrough (web simulation)

Driven through Chrome at a 412×915 viewport (matching the Redmi 14C's 20:9
panel). Captured from the app's own platform-activity log, which is rendered on
the Device setup page.

### 3.1 Configure and arm

| Step | Observed |
|---|---|
| Entered name `Dr. Silva` | avatar updated to initials `DS` |
| Entered number `0771234567` | header read `Dr. Silva / 0771234567` |
| Selected the `15s` preset | chip selected |
| Tapped **Schedule incoming call** | `Incoming call armed. Lock the screen to test the takeover.` |
| Countdown chip | `Incoming call in 14s`, ticking |
| Tapped **Schedule** with an empty number | `Enter a phone number first — it goes into the call log.` — validation works |

The last row is a control case: the arm button was pressed with no number and
correctly refused rather than arming a call with no identity.

### 3.2 Alarm fires → Module 2 → Module 3 → Module 4

Platform log, in order:

```
[web-bridge] alarmFired
[web-bridge] launchIncomingCall
[web-bridge] setLockScreenTakeover:true
[web-bridge] setKeepScreenOn:true
[web-bridge] setVoiceCommunicationMode:true
[web-bridge] startRinger(vibrate=true)
[ringer] started (vibrate=true)
[orchestrator] ringing: Dr. Silva <0771234567>
```

The incoming-call screen rendered with: `Incoming call` label, `DS` avatar,
`Dr. Silva`, `0771234567`, a `SIM 1` chip, an animated `Ringing` waveform, a
`Vibrating` indicator, Decline (red) / Answer (green) buttons, a `Keyguard held`
chip, and the volume-key hint. No layout overflow at 412×915.

### 3.3 Volume-key mute (Module 4)

Pressed the physical-volume-key stand-in (`ArrowDown`):

```
[web-bridge] hostKey:ArrowDown
[web-bridge] silenceRinger
[ringer] silenced by volume key
```

UI changed to `Ringer silenced — call still incoming`; the call screen stayed up
and the phase remained `ringing`. `document.querySelectorAll('audio').length`
was `0` throughout.

### 3.4 Answer (Module 5)

```
[incoming] answer tapped
[web-bridge] stopRinger
[ringer] stopped
[web-bridge] startProximityMonitoring
[proximity] monitoring started
[orchestrator] answered
```

Active-call screen rendered: caller name, timer `00:00` → `01:41` (ticking),
`In call`, `Proximity FAR — display on`, and the Mute / Keypad / Speaker /
Add call row with the red End call button. Audio element count: `0`.

### 3.5 End call and call-log write (Module 5 → Module 6)

```
[active] end call tapped
[web-bridge] stopRinger
[web-bridge] stopProximityMonitoring
[proximity] monitoring stopped
[web-bridge] setKeepScreenOn:false
[web-bridge] setVoiceCommunicationMode:false
[web-bridge] setLockScreenTakeover:false
[web-bridge] hideOverlay
[web-bridge] writeNativeCallLog(no-provider)
[call-log] Incoming 0771234567 appRow=true native=false
[orchestrator] ended (answered)
```

Every resource released exactly once, in the right order, before the log write.
The confirm sheet (`End this call?`) gated the action.

Call Log page rendered one grouped row under `TODAY`:

```
Dr. Silva   0771234567 • Incoming   05:36   02:06
```

with the honest banner: *"This platform has no system call-log provider, so only
the in-app mirror is written. The CallLog.Calls write is Android-only."*

### 3.6 Quick trigger (Module 2 fallback)

Tapped **Quick trigger — rings in 10s** without re-typing anything; the alarm
fired and the identical incoming-call screen appeared. Confirms the persisted
profile is sufficient on its own.

---

## 4. Defects found and fixed during this work

These are recorded because the fixes are load-bearing, not incidental.

| # | Defect | Symptom | Root cause | Fix |
|---|---|---|---|---|
| 1 | **Alarm fired with nobody listening** | The countdown reached zero, the chip said `Ringing now`, but the incoming-call screen never appeared. | The alarm payload was emitted on `launchTriggerStream`, and the pages subscribed to that stream — but `beginRinging` was never called by anything. An alarm that fires while no page is mounted produced an event nobody handled. | Added `LaunchDispatcher`, a single subscriber that translates platform events (`volumeKeyPressed` / `callIncoming` / `quickRing`) into call-flow actions, started from the app root. Pages no longer subscribe. |
| 2 | **Incoming-call screen overflowed a short viewport** | `RenderFlex overflowed by 31 pixels on the bottom` in the widget test. | Three `Spacer`s distributed the vertical space. Fine on a 6.7" panel; broken on a shorter viewport, in landscape, or at a large system font — i.e. a call screen that cannot render is a screen that cannot be answered. | Replaced the flex layout with fixed top/bottom chrome and a scrollable middle. |
| 3 | **Answer/Decline were not reliably tappable** | Widget-test taps on the label did not trigger the action. | The `GestureDetector` was on the circle only; the label sat beside it in the column. A user aiming at the label got nothing — fatal on a ringing screen. | Wrapped the whole action (circle + label) in one `InkWell` with a `Semantics` button node, and added `ValueKey`s. |
| 4 | **Widget tests hung on `pumpAndSettle`** | All widget tests timed out. | `BuildInfoBadge` reached for the global `BridgeService.instance.bridge`, which resolves to a real `MethodChannel`; under `flutter_test` that never completes. A real isolation defect, not a test artefact. | The bridge is now held on `AppScope` and injected. `AppScopeFactory.create()` for production, `.build(bridge:, store:)` for tests. |
| 5 | **Volume-key mute was a toggle** | A second press would have resumed the ringer. | Not originally guarded. | `RingerService.silenceForVolumeKey` is idempotent; pinned by test 7. |

---

## 5. Spec §7 checklist — honest status

| # | Check | Status | Evidence / blocker |
|---|---|---|---|
| 1 | **Screen-off test** — schedule for 1 min, lock, verify the screen wakes over the lock screen | ⛔ **NOT VERIFIED** | Needs the handset. The native path (`CallWindowController.acquire`, `FLAG_SHOW_WHEN_LOCKED` + `setShowWhenLocked` + keyguard dismiss) compiles but has not run. Note: a **secure** keyguard is deliberately not dismissed — Android refuses, and attempting it triggers the Xiaomi "unlock to continue" lockout. The call screen is shown *over* the keyguard instead. |
| 2 | **Proximity test** — answer, cover the bezel, verify the display goes dark and returns | ⛔ **NOT VERIFIED** | Needs the sensor. `ProximityController` uses a real `PROXIMITY_SCREEN_OFF_WAKE_LOCK`. The *state plumbing* around it is verified (test 9); the panel behaviour is not. |
| 3 | **Silence verification** | ✅ **VERIFIED (web)** | `document.querySelectorAll('audio')` and `('video')` both returned `0` during ringing, active, and after hang-up. No audio element is ever constructed. The native path sets `MODE_IN_COMMUNICATION` and plays nothing, but that was not executed. |
| 4 | **Volume-key mute** | ✅ **VERIFIED (logic)** / ⛔ device | The full path — key event → `RingerService.silenceForVolumeKey` → `silenceRinger` → screen stays up → second press ignored — is verified. The native `onKeyDown` interception compiles; the physical key was not pressed. |
| 5 | **Native call log** | ⛔ **NOT VERIFIED** | Needs the `CallLog.Calls` provider. `CallLogWriter` compiles and is wired; the browser honestly returns `false`. The in-app mirror row is verified, including the `TYPE_INCOMING` + `MISSED_REASON` semantics and the `0`-duration rule for a declined call. |

---

## 6. What to do on the Redmi 14C

1. Enable the five HyperOS settings in the README table (Autostart, no
   restrictions, pop-up windows, Alarms & reminders, notifications).
2. Grant `WRITE_CALL_LOG` when prompted — a Play-protect-signed build will not
   get it silently. Without it, `CallLogWriter` logs
   `WRITE_CALL_LOG not granted; skipping native write` and the call is absent
   from the Phone app while everything else works. This is the single most
   likely "the app is broken" report.
3. Work the §7 checklist top to bottom.
4. If a call does not appear, open **Device setup → Diagnostics**. It shows the
   ordered platform log — `scheduleExactAlarm`, `alarmFired`,
   `launchIncomingCall`, `startRinger` — which distinguishes "the alarm never
   registered" (permission/autostart) from "the alarm fired but the screen was
   blocked" (pop-up windows) from "the screen appeared" (nothing to fix).

---

## 7. Residual risks

| Risk | Why it matters | Mitigation in place |
|---|---|---|
| `WRITE_CALL_LOG` is a signature-level permission | Not grantable at runtime on a normally-signed build; the call log silently omits the row. | Logged explicitly; the app does not report the native write as successful when it failed. |
| HyperOS "Display pop-up windows" is not an AOSP permission | It has no standard intent, so the deep link falls back to app details. | Setup page prints the literal path for the user to follow by hand. |
| Autostart has no public API | Cannot be queried or enabled programmatically. | Reported as granted only when the app-details screen resolves; the guide always shows the manual path. |
| Secure keyguard is not dismissed | By design — see checklist row 1. | The call is shown over the keyguard instead, which matches how a real call behaves. |
| `CallLog.Calls` column values are literals | `MISSED_REASON_REJECTED` is not a public framework constant and resolves inconsistently across API levels. | Each literal is documented inline with its meaning and the reasoning. |
