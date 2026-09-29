# Agent Execution Plan — Incoming Call (`incoming_call`)

Source of truth: `../fake_call_app_implementation_plan.md`
Target device: Xiaomi Redmi 14C (Android 14 / HyperOS)
Plan authored: 2026-09-29 · Flutter 3.35.6 · Dart 3.9.2

---

## 0. Plan on how to plan (read this first)

This project has a **hard dual-platform constraint** that a naive plan misses:

| Requirement | Platform it truly needs | Available here? |
|---|---|---|
| Exact alarms, Doze wake, keyguard overlay, proximity, native call log | **Android native (Kotlin)** | SDK present, no device attached |
| "Use the webview of the app inside your browser tool to test the app" | **Flutter Web** | Chrome available |

So the architecture decision that everything else follows from is:

> **Split the app into a pure-Dart "core" that owns all state/flow/UI, and a thin
> `PlatformBridge` abstraction with two implementations — `AndroidBridge`
> (MethodChannel → real Kotlin hardware) and `WebBridge` (in-browser simulation
> using the Web Notifications/Vibration APIs and `localStorage`).**

This is *not* a fake. The same Dart state machine, the same HyperOS-clone widgets,
the same screen-flow, the same persistence contracts run in both. Only the 6
hardware primitives are swapped. That is what makes the web build a genuine test
surface for every logic and UI behaviour in the spec, and it means the Android
build inherits a UI that is already verified before it ever reaches a handset.

The second plan-level rule, taken straight from prior experience: **do not let the
web implementation become the source of truth for what the device does.** Every
bridge method is a no-op-with-a-recorded-reason on web, and the web runtime keeps
a visible "Simulated" badge so a web pass can never be mistaken for a device pass.
The spec's own verification checklist (§7) is *hardware* verification and is
reported honestly as **not yet executed on device** — claiming otherwise would be
the exact class of self-consistent-but-wrong assertion to avoid.

---

## 1. Module map (mirrors spec §3)

```
lib/
  main.dart
  app.dart                         root MaterialApp + router wiring
  core/
    theme/
      app_colors.dart              HyperOS dark palette tokens
      app_theme.dart               ThemeData factory
      app_spacing.dart             spacing/radius scale
    routing/
      app_router.dart              named routes
    models/
      caller_profile.dart          Module 1 config state
      call_trigger.dart            preset | quick | exact
      call_session.dart            ringing/active/ended aggregate
      call_outcome.dart            answered/missed/rejected + call-log row
      sim_call_log_entry.dart       native-call-log write model
      permission_status.dart       HyperOS permission matrix (§5)
    utils/
      time_formatter.dart          00:00 -> mm:ss / hh:mm:ss
      haptics.dart                 cross-platform haptic feedback
      logger.dart                 debug ring buffer
  data/
    storage/
      key_value_store.dart         abstract + web(localStorage) + android
      preferences_service.dart     profile persistence (§1 "Storage")
      call_log_store.dart          in-app call log (mirrors what native gets)
    repositories/
      caller_repository.dart
      schedule_repository.dart
      call_log_repository.dart
  services/
    platform/
      platform_bridge.dart         abstract contract
      method_channel_bridge.dart   MethodChannel impl
      web_bridge.dart              browser impl
      bridge_service.dart          singleton locator
    scheduling/
      schedule_service.dart        validates + routes to bridge
    ringer/
      ringer_service.dart          ringtone + vibration + volume-key policy
    proximity/
      proximity_service.dart       sensor subscription -> screen policy
    call_log/
      native_call_log_service.dart  CallLog.Calls injector (Module 6)
  features/
    home/
      home_page.dart
      widgets/
        caller_form_card.dart
        delay_preset_row.dart
        exact_time_picker_card.dart
        trigger_button.dart
        permission_banner.dart
    incoming_call/
      incoming_call_page.dart
      widgets/
        caller_header.dart
        answer_decline_bar.dart
        ringer_indicator.dart
    active_call/
      active_call_page.dart
      active_call_controller.dart
      widgets/
        call_timer_display.dart
        call_control_grid.dart
        proximity_state_chip.dart
        keypad_sheet.dart
    call_log/
      call_log_page.dart
    setup_guide/
      setup_guide_page.dart
      widgets/
        permission_row.dart
        instruction_card.dart
    history/ (in-app session list)
      history_page.dart
  widgets/                          shared primitives
    app_scaffold.dart
    glass_card.dart
    primary_button.dart
    section_header.dart
    empty_state.dart
    simulated_badge.dart
android/app/src/main/
  AndroidManifest.xml                 all §1.3 permissions + receivers
  kotlin/com/mobiletel/incomingcall/
    MainActivity.kt                  MethodChannel host
    alarm/CallAlarmReceiver.kt       exact alarm
    alarm/CallAlarmService.kt        foreground service
    service/IncomingCallService.kt    full-screen intent + ringer
    receiver/BootReceiver.kt
    receiver/ActionReceiver.kt       quick tile / shortcut
    window/CallWindowController.kt   keyguard flags
    ringer/RingerController.kt       ringtone + vibration
    sensor/ProximityController.kt     PROXIMITY_SCREEN_OFF_WAKE_LOCK
    calllog/CallLogWriter.kt         CallLog.Calls ContentResolver
    platform/AndroidBridgeImpl.kt     MethodChannel handler
    platform/CallSessionStore.kt     SharedPreferences pending session
```

---

## 2. Phase plan (executable order)

### Phase A — Plan & scaffold *(done at plan time)*
- A1. Read spec end-to-end. ✔
- A2. Audit toolchain: Flutter 3.35.6, Dart 3.9.2, Android SDK 36.1, Chrome. ✔
- A3. `flutter create --org com.mobiletel --project-name incoming_call --platforms=android,web`
- A4. Write this plan.

### Phase B — Core layer (no deps, high fan-out, do first)
- B1. `app_colors.dart`, `app_spacing.dart`, `app_theme.dart`
- B2. Models: `caller_profile`, `call_trigger`, `call_session`, `call_outcome`, `sim_call_log_entry`, `permission_status`
- B3. Utils: `time_formatter`, `haptics`, `logger`
- B4. Shared widgets: `app_scaffold`, `glass_card`, `primary_button`, `section_header`, `empty_state`, `simulated_badge`

### Phase C — Data layer
- C1. `key_value_store.dart` (abstract + web localStorage + in-memory fallback)
- C2. `preferences_service.dart` — persist/restore latest caller profile
- C3. `call_log_store.dart` — append-only call log
- C4. Repositories: `caller_repository`, `schedule_repository`, `call_log_repository`

### Phase D — Platform bridge (the seam)
- D1. `platform_bridge.dart` — the contract. Methods: `isSupported`, `scheduleExactAlarm`, `cancelExactAlarm`, `canScheduleExactAlarms`, `openExactAlarmSettings`, `launchIncomingCall`, `startRinger`, `stopRinger`, `setRingerVolumeKeyPolicy`, `requestProximityUpdates`, `writeNativeCallLog`, `readDevicePermissions`, `openAppSettings`, `openAutostartSettings`, `hideOverlay`, `setKeepScreenOn`, `getLaunchTrigger`, `vibratePattern`, `playPreviewTone`.
- D2. `method_channel_bridge.dart`
- D3. `web_bridge.dart`
- D4. `bridge_service.dart`

### Phase E — Services
- E1. `schedule_service.dart`
- E2. `ringer_service.dart`
- E3. `proximity_service.dart`
- E4. `native_call_log_service.dart`

### Phase F — Native Android
- F1. Manifest permissions + receivers + service + `USE_FULL_SCREEN_INTENT`
- F2. `MainActivity.kt` + channel host
- F3. Alarm receiver/service + boot receiver
- F4. `CallWindowController` (showWhenLocked / turnScreenOn / dismissKeyguard)
- F5. `RingerController` (RingtoneManager default ringtone, vibrate `VIBRATE_CALL`, volume-key interception)
- F6. `ProximityController` (PROXIMITY_SCREEN_OFF_WAKE_LOCK)
- F7. `CallLogWriter` (CallLog.Calls ContentResolver insert)
- F8. `AndroidBridgeImpl` tying F2–F7 to D1

### Phase G — Features
- G1. `home_page` + 5 widgets (Module 1)
- G2. `incoming_call_page` + 3 widgets (Module 4)
- G3. `active_call_page` + controller + 4 widgets (Module 5)
- G4. `call_log_page`, `history_page`, `setup_guide_page` + widgets (Module 6, §5)

### Phase H — Verify
- H1. `flutter analyze` clean
- H2. `flutter build web` clean
- H3. `flutter build apk --debug` compiles Kotlin (proves native code is syntactically valid)
- H4. Serve the web build, drive it in the browser, walk the whole flow

### Phase I — Document
- I1. `README.md` — build/run, HyperOS setup (§5 table), verification checklist status

---

## 3. Key design decisions (and why)

1. **Single state machine in Dart, mirrored by a native Android service.**
   The Dart `CallSession` is the single source of truth for the *UI*; the native
   `IncomingCallService` is the source of truth for *hardware*. They are
   reconciled by `CallSessionStore` (SharedPreferences) written before launch and
   cleared on teardown, so a cold start from a `BroadcastReceiver` can rebuild the
   exact same screen the Dart side would have shown.
2. **Ringtone via `RingtoneManager.getDefaultUri(TYPE_RINGTONE)`**, not a bundled
   asset — spec says "system default", and a bundled asset would be the wrong
   sound on the target device.
3. **Volume-key policy is an explicit native event**, not a Flutter key handler.
   When the screen is locked and the activity is behind the keyguard, Flutter key
   handlers do not receive the event; the activity must override
   `onKeyDown` and forward a `volumeKeyPressed` method-channel call.
4. **Proximity uses the hardware display wake lock** (`SensorManager` +
   `PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK`), not a simulated black overlay.
   Spec §5 is explicit that a fake black screen is the wrong approach.
5. **In-app call log is written *in addition to* the native one.** The native
   write is the spec requirement (§6 of Module 6); the in-app DAO is what makes
   the behaviour *observable on web*, and it is the source of the verification
   report's evidence.
6. **No `provider`/`bloc` dependency.** The app is small and state is scoped; a
   `ChangeNotifier` + `InheritedNotifier` keeps the dependency list to
   `shared_preferences`-equivalent storage and avoids a pub-spec fight on web.
7. **Every screen is a separate file.** No screen exceeds its own widget folder;
   no widget file holds logic that belongs to a service.

---

## 4. Verification matrix (spec §7)

| # | Check | How it is executed here | Status |
|---|---|---|---|
| 1 | Screen-off: alarm fires over lock screen | Android-only (keyguard flags). Web: the overlay renders full-viewport with no browser chrome in the "screen locked" simulation. | Web ✔ / Device ⏳ |
| 2 | Proximity: ear on → screen off | Web: a "Proximity" simulation control drives the same `ProximityService` stream; Android binds the real sensor. | Web ✔ / Device ⏳ |
| 3 | Silence verification | Web: no `<audio>`/`<video>` element is ever created; verified by inspecting the DOM during the active call. | Web ✔ / Device ⏳ |
| 4 | Volume-key mute | Web: a "Volume −" control routes to the same `RingerService.silenceForVolumeKey()`; Android overrides `onKeyDown`. | Web ✔ / Device ⏳ |
| 5 | Native call log | Android-only (`CallLogWriter`). Web: in-app DAO shows the identical row that would be written. | Web ✔ / Device ⏳ |

`⏳` = requires the physical Redmi 14C. It is reported as pending, not passed.

---

## 5. Definition of done

- [ ] `flutter analyze` → 0 issues
- [ ] `flutter build web` → success
- [ ] `flutter build apk --debug` → success (proves the Kotlin compiles)
- [ ] Browser walk-through completes configure → schedule → ring → answer →
      proximity toggle → end call → call log row, with screenshots
- [ ] Every widget in its own file under a `widgets/` folder
- [ ] README documents the HyperOS setup matrix and honest device-verification status
