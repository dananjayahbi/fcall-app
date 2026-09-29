# Incoming Call — Xiaomi Redmi 14C / HyperOS call alert

Schedules realistic incoming telephone calls on an Android 14 handset, replicates
the stock HyperOS dialer UI, drives genuine system ringtones and haptics, holds
the hardware proximity wake lock, and writes the finished call into the native
`CallLog.Calls` history.

Built from `fake_call_app_implementation_plan.md`. The execution plan lives in
[`agent-plan-playground/AGENT_PLAN.md`](agent-plan-playground/AGENT_PLAN.md).

---

## Architecture in one picture

```
                       ┌──────────────────────────────┐
   screens (Dart)      │  Home · IncomingCall ·       │
   widgets (Dart)      │  ActiveCall · CallLog ·      │
   services (Dart)     │  SetupGuide                  │
                       │  CallOrchestrator ← the      │
                       │  single state machine        │
                       └──────────────┬───────────────┘
                                      │  PlatformBridge (interface)
                    ┌─────────────────┼──────────────────┐
                    ▼                 ▼                  ▼
             MethodChannelBridge  WebPreviewBridge   HeadlessBridge
                    │                 │                  │
            ┌───────┴───────┐         │            (tests)
            │  Kotlin       │    browser-backed
            │  AlarmManager │    (vibration,
            │  Foreground   │     localStorage)
            │  Proximity    │
            │  CallLog.Calls│
            └───────────────┘
```

Everything above the bridge line is pure Dart and identical on both platforms.
Only six hardware primitives are swapped: exact alarms, lock-screen takeover,
ringtone/vibration, volume-key interception, proximity, and the call-log write.

### Naming: nothing on screen identifies the app

The app must be indistinguishable from an ordinary call alert, so the following
are enforced and cannot regress:

| Surface | Value | Why |
|---|---|---|
| Launcher label / app bar | `Incoming Call` | "Fake Call" in the launcher gives it away instantly |
| Android package | `com.mobiletel.incomingcall` | appears in App info, permissions, and log output |
| Dart package | `incoming_call` | appears in the web tab title and build output |
| Notification channel | `Incoming calls` | visible in Android's notification settings |
| Method channel ids | `com.mobiletel.incomingcall/*` | the Dart↔Kotlin contract; both sides must match |
| Call screens | caller, ringer, actions — nothing else | no badge, no chips, no branding, no hints |
| Diagnostics | long-press the app bar title | undiscoverable on purpose; keeps the platform log reachable |

`test/widget_test.dart` asserts that no screen renders the words *simulat*,
*fake*, *preview*, *stub*, *headless*, *web* or *test*. That test has already
caught two real leaks ("Web simulation" badge, "Test ring" button).

### Why the screen is derived from the phase, not a route

`CallFlowHost` renders the visible screen from `CallSession.phase`. This is not
a stylistic choice. On Android the call is launched by a `BroadcastReceiver`
that can start the app cold, with **no navigation history at all**. "Push the
incoming-call page" is not a reliable primitive in that situation; deriving the
screen from the phase works identically whether the app was already running or
was just woken from Doze.

---

## Project layout

```
lib/
  app.dart                     root + dispatcher bootstrap
  main.dart                    entry point
  core/
    app_scope.dart             DI container (bridge is injectable here)
    routing/                   call_flow_host.dart, app_router.dart
    models/                    caller_profile, call_trigger, call_session,
                               call_outcome, permission_status
    theme/                     app_colors, app_spacing, app_theme
    utils/                     time_formatter, logger
  data/
    storage/                   key_value_store, storage_factory, web adapters
    repositories/              caller, settings, call_log_store
  services/
    platform/                  platform_bridge + android/web/headless impls
    scheduling/                schedule_service
    ringer/                    ringer_service
    proximity/                 proximity_service
    call_log/                  native_call_log_service
    call_orchestrator.dart     the §4 state machine
    launch_dispatcher.dart     platform events -> call-flow actions
  features/
    home/ incoming_call/ active_call/ call_log/ setup_guide/
      widgets/                 one file per widget, no monoliths
  widgets/                     shared primitives

android/app/src/main/kotlin/com/mobiletel/incomingcall/
  MainActivity.kt              MethodChannel host + volume-key interception
  platform/                    AndroidBridgeImpl, CallSessionStore, storage
  alarm/                       CallAlarmScheduler, CallAlarmReceiver
  service/                     IncomingCallService (foreground)
  window/                      CallWindowController (keyguard flags)
  ringer/                      RingerController (Ringtone + Vibrator)
  sensor/                      ProximityController (wake lock)
  calllog/                     CallLogWriter (ContentResolver)
  receiver/                    ActionReceiver (quick tile + reboot rearm)
test/                          22 tests (flow ordering + screen phase)
```

---

## Build & run

```bash
flutter pub get

# Android (the real target)
flutter run -d <your-redmi-14c>
flutter build apk --release

# Web (logic/UI harness — see "What the web build is and is not")
flutter run -d chrome
flutter build web --release --no-web-resources-cdn --pwa-strategy=none

# Tests
flutter test
flutter analyze
```

Toolchain used: Flutter 3.35.6 · Dart 3.9.2 · Android SDK 36.1 · JDK 18.
`compileSdk`/`targetSdk` follow the Flutter defaults, which target API 36 — well
above the API 34 the Redmi 14C runs.

### Release signing

Release builds are signed with an upload key, **not** the debug key. Gradle
falls back to the debug key when no keystore is configured so a fresh clone can
still produce an installable artefact — but a debug-signed release cannot be
published to Play and will not install over a properly signed build. **Always
confirm which key was used:**

```bash
$ANDROID_SDK/build-tools/36.1.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
# expect: Signer #1 certificate DN: CN=Incoming Call, O=MobileTel
# a build that says  CN=Android Debug  was NOT signed with the upload key
```

Two files are required and **both are gitignored**, so they never reach a
remote or a shared CI log:

| File | Contents |
|---|---|
| `android/key.properties` | `storeFile`, `storePassword`, `keyAlias`, `keyPassword` |
| `android/app/upload-keystore.jks` | RSA 4096, PKCS12, alias `upload`, 30-year validity |

> **Back these two up somewhere durable and outside the repo.** An Android app
> can only be updated by a build signed with the *same* key. Losing the key
> means every user has to uninstall before a new version can be installed —
> there is no override.

`storeFile` is resolved relative to the **app module** (`android/app/`), not to
the root project. Getting that wrong makes the existence check fail silently
and drops you back to the debug key — a "release" APK that verifies fine,
installs fine, and is still unpublishable.

---

## App icon

The launcher mark is a blue-gradient squircle with a white handset — generated
from code, not hand-drawn, so it can be re-derived and every density is exact.

```bash
python tool/logo/generate_icons.py
```

| File | Role |
|---|---|
| `tool/logo/refine_logo.py` | the mark itself: colours, geometry, glyph centring |
| `tool/logo/explore_logo.py` | renders design candidates + a scale ladder to review against |
| `tool/logo/generate_icons.py` | writes every density into `android/` and `web/` |

Design decisions, and why the obvious alternatives were rejected:

- **Squircle, not circle.** Android applies its own mask to adaptive icons, and a
  plain circle is indistinguishable from a contact photo. A gradient needs a
  shape to read as a brand mark.
- **Gradient, not flat.** The app is used in the dark, but a near-black icon is
  invisible on a dark wallpaper. The blue gradient is the one treatment legible
  on both.
- **Handset, not ringing bell.** At the 48px a launcher actually shows, the bell
  breaks into an unrecognisable arc; the handset keeps a closed silhouette.
- **No text.** The icon is visible on the lock screen before the app opens, so
  it obeys the same no-reveal rule as the UI.

Three variants ship, and they are not interchangeable:

| Variant | Glyph size | Used by |
|---|---|---|
| `ic_launcher.png` | 50% of tile | pre-Oreo launchers, shown unmasked |
| `ic_launcher_foreground.png` | 52% of a 108dp canvas | adaptive icons; the launcher masks it |
| `ic_launcher_monochrome.png` | silhouette only | Android 13+ themed icons (OS tints it) |
| `Icon-maskable-*.png` | 34%, full bleed | PWA — the *platform* applies the mask |

The glyph is centred on its **rendered pixels**, not on the font's em box: the
handset is drawn at 45°, so the two do not coincide, and centring on metrics
left it visibly high in the themed-icon layer.

---

## Required HyperOS setup (spec §5)

HyperOS blocks this app's core behaviour by default. The app detects this and
shows a banner, but the settings must be changed manually on the device.

| Setting | Path | Why |
|---|---|---|
| **Autostart** | Settings > Apps > Manage apps > Incoming Call > Autostart > **On** | HyperOS kills background workers that are not whitelisted; the alarm worker dies with them. |
| **Battery saver** | Settings > Apps > Manage apps > Incoming Call > Battery saver > **No restrictions** | The default "optimise background" policy kills the alarm timer when the screen turns off. |
| **Display pop-up windows** | Settings > Apps > Permissions > Other permissions > Incoming Call > Display pop-up windows while running in the background > **Allow** | Without it the alarm fires but the call screen cannot be drawn over other apps. |
| **Alarms & reminders** | Settings > Apps > Permissions > Other permissions > Incoming Call > Alarms & reminders > **Allow** | Android 13+ requires explicit consent before an app can register an alarm that survives Doze. |
| **Notifications** | Settings > Apps > Manage apps > Incoming Call > Notifications > **On** | Used for the heads-up path when the device is already unlocked. |

In-app: **Device setup** in the app bar lists the same matrix with per-item
state, a one-click deep link where the platform exposes one, and a live log of
what the bridge actually did.

### Permissions declared in the manifest

`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`,
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`,
`USE_FULL_SCREEN_INTENT`, `SYSTEM_ALERT_WINDOW`, `DISABLE_KEYGUARD`,
`EXPAND_STATUS_BAR`, `VIBRATE`, `MODIFY_AUDIO_SETTINGS`, `WRITE_CALL_LOG`,
`READ_CALL_LOG`, `READ_CONTACTS`, `READ_PHONE_STATE`.

`android.hardware.sensor.proximity` is declared **required** — without that
sensor, Module 5 cannot work at all.

---

## Notable implementation decisions

1. **The system ringtone, never a bundled asset.** `RingtoneManager.getDefaultUri(TYPE_RINGTONE)`.
   A bundled tone would be the single loudest tell that this is not a real call.
2. **Volume keys are intercepted natively, not in Dart.** When the activity sits
   behind the keyguard the Flutter view never receives key events, so a Dart
   `onKeyChanged` handler would not fire and the ringer would keep sounding.
   `MainActivity.onKeyDown` forwards the event over the channel instead.
3. **The volume-key mute is one-shot, not a toggle.** A second press must not
   resume the ringer; on a real handset one press mutes and the call screen
   stays. Asserted by a dedicated test.
4. **Proximity uses the hardware wake lock, not a black overlay.** Spec §5 is
   explicit. The wake lock makes the panel *physically* dark, so a camera or a
   screen recording sees nothing.
5. **Call-log `TYPE` is `INCOMING` for all three outcomes.** A declined call is
   still an incoming call; the outcome rides on `MISSED_REASON`
   (0 answered / 1 missed / 2 rejected). Writing `TYPE_MISSED` renders a
   declined call as a missed outbound call in the dialer.
6. **Duration is `0` for a non-answered call.** Recording ring time as duration
   makes a 1-minute rejection look like a 1-minute conversation.
7. **Ordering is asserted, not just final state.** The ringer must stop *before*
   proximity engages; the locks must be released *before* the call is logged.
   A state-only test passes with either order and leaves a device holding a
   wake lock.
8. **The bridge is injected through `AppScope`,** not looked up from a global in
   each widget. This is what makes the UI testable — a widget test that reaches
   the ambient bridge hangs, because a real `MethodChannel` never completes
   under `flutter_test`.
9. **The app writes its own call log *in addition to* the native one.** The
   native write is the spec requirement; the in-app DAO is what makes the
   behaviour observable on web and renderable immediately without a
   Contacts runtime-permission round-trip.

---

## What the web build is, and what it is not

The web build exists so the entire call flow, the HyperOS UI clone, and every
state transition can be exercised without a handset attached. It runs the
**same** Dart state machine, the **same** screens, and the **same** services.

It is a **simulation**, and the app says so on every screen with a persistent
`Web simulation` badge. Specifically, these are *not* real on web:

| Spec §7 check | Web | Device |
|---|---|---|
| Screen wakes over the keyguard | simulated chrome | real `FLAG_SHOW_WHEN_LOCKED` + `setShowWhenLocked` |
| Proximity blanks the display | manual control driving the same service | real `PROXIMITY_SCREEN_OFF_WAKE_LOCK` |
| Total silence | **verifiable** (no `<audio>` element is ever created) | verifiable |
| Volume-key mute | keyboard-driven through the same `RingerService` | real `onKeyDown` |
| Native call log | in-app mirror only; the bridge honestly returns `false` | real `CallLog.Calls` insert |

A green web run is evidence that the logic and the UI are correct. It is **not**
evidence that the hardware behaviours work. The Setup page lists all five items
un-ticked for exactly this reason.

**Where this report lives:** this README and
`agent-plan-playground/VERIFICATION_REPORT.md` are developer documentation. They
describe the internals in full, which is their job — they are never rendered by
the running app. The in-app surface deliberately carries none of it.

---

## Testing

```bash
flutter test        # 22 tests
flutter analyze     # 0 issues
```

`test/call_flow_test.dart` — 14 tests over the orchestrator using a recording
fake bridge, asserting the exact *order* of hardware calls.
`test/widget_test.dart` — 8 tests over the phase-driven screen swap, plus 4
that assert no internal terminology is ever rendered to the user.
