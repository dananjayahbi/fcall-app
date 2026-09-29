# Fake Call Simulator: Engineering Specification & Agent Directive

## 1. Project Overview & Objective
The objective is to build a Flutter application for personal use on a **Xiaomi Redmi 14C** (running Android 14 / Xiaomi HyperOS). The app schedules realistic incoming telephone calls, replicates the device's native incoming/active dialer UI, triggers genuine system vibrations and ringtones, operates in complete caller silence, and manages hardware state (proximity sensor screen-off) to remain indistinguishable from an authentic incoming phone call.

---

## 2. High-Level Architecture & Flow

```
+-----------------------------------------------------------------------------------+
|                              1. CONFIGURATION PHASE                               |
|                                                                                   |
|  [ User Input Screen ]                                                            |
|  - Caller Name & Number                                                           |
|  - Delay Timer (Presets: 15s, 1m, 5m, Custom Time/Date)                           |
|  - Immediate Trigger Shortcut (Widget / Notification tile)                        |
+------------------------------------------+----------------------------------------+
                                           |
                                           v
+-----------------------------------------------------------------------------------+
|                         2. BACKGROUND SCHEDULING LAYER                            |
|                                                                                   |
|  [ Exact Alarm Scheduler ]                                                        |
|  - Schedules exact wakeup using Android AlarmManager                              |
|  - Configured to ignore device Doze/Battery saver state                           |
|  - Survives background memory clearing                                            |
+------------------------------------------+----------------------------------------+
                                           | (Timer fires when phone locked/idle)
                                           v
+-----------------------------------------------------------------------------------+
|                          3. LOCK-SCREEN TAKEOVER LAYER                            |
|                                                                                   |
|  [ System Broadcast Receiver & Window Manager ]                                   |
|  - Turns screen on                                                                |
|  - Bypasses keyguard / displays over lock screen                                  |
|  - Initializes system default phone ringtone & haptic vibration pattern           |
+------------------------------------------+----------------------------------------+
                                           |
                                           v
+-----------------------------------------------------------------------------------+
|                          4. INCOMING CALL SIMULATION                              |
|                                                                                   |
|  [ Xiaomi Redmi 14C / HyperOS Call UI Clone ]                                     |
|  - Contact Name, Number, Location tag ("Incoming call...")                        |
|  - Answer / Decline gesture targets (Swipe or Tap depending on HyperOS layout)    |
+---------------------+---------------------------------------------+---------------+
                      |                                             |
     (User Swipes / Taps Answer)                         (User Declines / Timeout)
                      |                                             |
                      v                                             v
+---------------------------------------------+   +---------------------------------+
|          5. ACTIVE CALL SIMULATION          |   |     TERMINATION & RECORDING     |
|                                             |   |                                 |
|  [ In-Call Screen & Hardware Controller ]   |   | - Stop ringtone & vibration     |
|  - Stop ringtone instantly                  |   | - Inject Missed/Rejected call   |
|  - Start call duration timer (00:00 -> ...) |   |   into Android native Call Log  |
|  - Maintain total audio silence (no voice)  |   | - Close app to home/lock screen |
|  - Proximity Sensor Lock:                   |   +---------------------------------+
|    * Ear detected  -> Screen shuts OFF      |
|    * Ear removed   -> Screen turns ON       |
|  - In-call controls (Mute, Keypad, Speaker) |
|  - End Call Action                          |
+---------------------+-----------------------+
                      |
           (User Taps End Call)
                      |
                      v
+-----------------------------------------------------------------------------------+
|                        6. POST-CALL PERSISTENCE LAYER                             |
|                                                                                   |
|  [ Native Call Log Provider ]                                                     |
|  - Writes completed call record (Name, Number, Duration, Timestamp)               |
|    directly into Android's native dialer history                                  |
|  - Cleans up wakelocks, releases sensors, safely exits screen                     |
+-----------------------------------------------------------------------------------+
```

---

## 3. Module Specifications & Responsibilities

### Module 1: Scheduling & Configuration Screen (Flutter UI)
* **Configuration State:**
  * Contact identity: Customizable caller name, phone number, and optional profile photo/avatar.
  * Trigger mechanisms:
    * Quick Presets: 15 seconds, 30 seconds, 1 minute, 5 minutes.
    * Exact Time Picker: Date and time selector for future appointments.
  * Audio & Vibration Toggles: Use system default ringtone or custom internal tone; toggle vibration pattern.
* **Storage:**
  * Persist the latest configured caller profile locally so the user can re-trigger instantly without re-typing credentials.

### Module 2: Background Scheduling & Wake Engine
* **Execution Contract:**
  * Must schedule an exact trigger timestamp via the platform's exact alarm scheduling mechanisms.
  * Must specify wake-up flags capable of rousing the CPU from deep sleep (Android Doze mode).
* **Alarm Receiver Action:**
  * When the alarm fires, execute a foreground service or direct full-screen activity invocation.
  * If the device is unlocked, trigger a high-priority heads-up notification with action buttons.
  * If the device is locked, wake the screen immediately and present the full-screen call view.

### Module 3: Lock-Screen & Window Management (Native Android Integration)
* **Window Attributes Required on Call Screen Launch:**
  * Turn screen on automatically.
  * Render content over the secure keyguard/lock screen.
  * Keep the screen illuminated while ringing until an answer or rejection occurs.
  * Dismiss the keyguard gracefully upon answering.

### Module 4: Incoming Call Simulation Screen (HyperOS UI Clone)
* **Visual Representation:**
  * Pixel-accurate recreation of the Xiaomi Redmi 14C dialer (HyperOS / Google Phone layout standard on Global ROMs).
  * High-contrast dark or blurred wallpaper background.
  * Top half: Large contact name, secondary phone number, and caller metadata label ("Incoming call" or "SIM 1").
  * Center/Bottom: Incoming call action buttons.
    * Implement the exact interaction model of the target device: vertical swipe-up to answer, swipe-down to decline (or horizontal dual-button layout).
* **Audio & Haptic Feedback:**
  * Stream the Android system's configured incoming call ringtone via the ringtone audio channel.
  * Loop the standard phone vibration pattern continuously.
  * Intercept physical volume buttons: pressing either volume key must mute the ringer and stop vibration while keeping the incoming call screen active (matching real device behavior).

### Module 5: Active Call Simulation & Hardware Engine
* **State Upon Answering:**
  * Ringtone and vibration must terminate instantly without audio tail or delay.
  * Screen transitions immediately to the in-call layout.
  * Call timer starts from `00:00` and ticks up once per second.
* **Audio Behavior:**
  * Total audio silence. No outgoing or incoming audio files played.
  * Audio manager stream switched to voice communication mode so the system handles hardware state as an authentic active phone call.
* **Hardware Proximity Management:**
  * Must bind directly to the Android proximity sensor.
  * When the phone approaches the user's face/ear, activate the hardware display wake lock to shut down screen illumination and disable touch input.
  * When moved away from the face, re-enable screen illumination and touch input instantly.
* **Call Actions:**
  * Functional "End Call" button (prominent red circular icon) that stops all timers and terminates the activity.
  * Dummy interactive UI buttons (Mute, Keypad, Speaker, Add Call) that toggle visual states but maintain silence.

### Module 6: System Call Log Persistence
* **Post-Call Recording:**
  * After the call is completed, rejected, or missed, write an entry to Android’s native call history database.
  * Parameters written: Target phone number, cached caller name, call type (Incoming / Missed / Rejected), timestamp of call start, and duration in seconds.
  * Result: If anyone asks the user to check their recent calls, the fake call appears inside the native Android phone app history.

---

## 4. Hardware & State Lifecycle Diagram

```
+-----------------------------------------------------------------------------+
|                           STATE MACHINE LIFECYCLE                           |
+-----------------------------------------------------------------------------+

       [ IDLE / CONFIGURING ]
                 |
                 | (Schedule Set)
                 v
       [ ALARM REGISTERED ]
                 |
                 | (Alarm Timestamp Reached)
                 v
       [ DEVICE WAKEUP & KEYGUARD OVERLAY ]
                 |
                 +--------------------------------+
                 |                                |
                 v (Device Locked)                v (Device Unlocked)
       [ FULL-SCREEN RINGING UI ]        [ HEADS-UP NOTIFICATION ]
                 |                                |
                 +----------------+---------------+
                                  |
                                  | (User Answers)
                                  v
                    +---------------------------+
                    |    ACTIVE CALL RUNNING    |
                    |    - Call Timer Active    |
                    |    - Complete Silence     |
                    +-------------+-------------+
                                  |
            +---------------------+---------------------+
            |                                           |
            v (Proximity Sensor = NEAR)                 v (Proximity Sensor = FAR)
    +-----------------------+                   +-----------------------+
    |  SCREEN OFF / LOCKED  |                   |   SCREEN ON / ACTIVE  |
    |  (Phone at ear)       |                   |   (Phone held away)   |
    +-----------+-----------+                   +-----------+-----------+
                |                                           |
                +---------------------+---------------------+
                                      |
                                      | (User Taps "End Call")
                                      v
                        [ CALL TERMINATED ]
                                      |
                                      v
                        [ WRITE NATIVE CALL LOG ]
                                      |
                                      v
                        [ CLEAN EXIT TO SYSTEM ]
```

---

## 5. Device-Specific Configuration Matrix: Xiaomi Redmi 14C (HyperOS)

AI Agents must configure the project and generate documentation alerting the user to adjust the following settings in HyperOS:

| Feature / Setting | Xiaomi HyperOS Requirement | Agent Implementation Directive |
|---|---|---|
| **Display Pop-Up Windows in Background** | Restricted by default in HyperOS. Blocks background alarm activities from showing. | Include a UI setup banner or permission-check routing user to: `Settings > Apps > Permissions > Other permissions > [App Name] > Display pop-up windows while running in the background`. |
| **Autostart Permission** | HyperOS terminates background workers without Autostart enabled. | Include intent trigger or explicit instruction to enable `Autostart` in App Info. |
| **Battery Saver Mode** | Kills background timers after screen turns off. | Direct user to set App Battery Saver to `No Restrictions`. |
| **Exact Alarm Permission** | Android 13/14 requires explicit permission to schedule exact wakeups. | Declare exact alarm permissions in the manifest and verify access before scheduling. |
| **Lockscreen Flags** | Modern Android requires specific window flags on activity creation. | Implement activity configuration for `showWhenLocked`, `turnScreenOn`, and keyguard dismissal flags. |
| **Proximity Sensor Access** | Standard sensor listener vs. Display WakeLock. | Implement platform channel binding to `PROXIMITY_SCREEN_OFF_WAKE_LOCK` for native screen shutdown rather than manual black screens. |

---

## 6. Step-by-Step Implementation Sequence for AI Agents

Follow this execution order when scaffolding and generating code:

### Phase 1: Project Setup & Platform Channel Scaffolding
1. Initialize the Flutter project with appropriate bundle identifiers.
2. Configure Android build files targeting Android 14 (API 34) to match the Redmi 14C.
3. Configure the Android Manifest with permissions for:
   * Exact alarms and wake locks.
   * Full-screen intent and system alert window permissions.
   * Vibration and ringtone access.
   * Native Call Log read/write access.
4. Set up an Android `MethodChannel` in the main Android activity to handle:
   * Window flag updates for lock-screen takeovers.
   * PowerManager proximity wake lock acquisition and release.

### Phase 2: Background Scheduling Engine
1. Integrate background alarm scheduling capable of executing an isolated entry point when the device is idle.
2. Establish the callback dispatcher that triggers the incoming call view when the scheduled time arrives.
3. Implement a fallback quick-trigger: add an app shortcut or home screen action that sets a 10-second countdown immediately.

### Phase 3: Hardware Sensor & Audio Control
1. Implement ringtone playback utilizing system default telephony audio tracks.
2. Implement looped vibration patterns mimicking incoming cellular calls.
3. Hook hardware volume key events on Android to silence audio/vibration while keeping the screen displayed.
4. Establish the proximity sensor interface so that answering the call immediately engages the screen-off wake lock whenever the sensor reads near-field obstruction.

### Phase 4: User Interface Implementation
1. **Config Screen:** Build the scheduler form with preset buttons (15s, 1m, 5m), name/number text fields, and a trigger button.
2. **Incoming Call Screen:** Construct the HyperOS-styled dialer screen:
   * Profile circle, large caller typography, green/red interaction buttons or swipe target.
   * Full-screen immersion with transparent navigation bars.
3. **Active Call Screen:**
   * Stopwatch timer incrementing every second.
   * Grid of call controls (Mute, Keypad, Audio, End Call).
   * Red termination button bound to call cleanup routines.

### Phase 5: Call Log Provider & Clean Exit
1. Build the call-history injector service to write simulated call records into Android's native `CallLog.Calls` content provider.
2. Add graceful dismissal logic: upon call conclusion, release proximity locks, restore audio channels, clear window flags, and terminate the activity to return the user to their launcher or previous app without flickering.

---

## 7. Verification & Edge Case Checklist

Before concluding development, the AI Agent must verify the following scenarios:
* [ ] **Screen-Off Test:** Schedule a call for 1 minute in the future. Lock the phone. Wait for the alarm. Verify the screen wakes up automatically, turns on, and displays the call UI over the lock screen.
* [ ] **Proximity Test:** Answer the call. Bring hand over the top bezel of the Redmi 14C. Verify the display turns completely off. Pull hand away; verify the display turns back on instantly with the timer still ticking.
* [ ] **Silence Verification:** Answer the call. Verify zero static, white noise, or audio files are emitted through either speaker.
* [ ] **Volume Button Mute:** When ringing, press the physical Volume Down button. Verify the ringtone and vibration cease while the call screen stays visible.
* [ ] **Native Log Check:** End the call. Open the default Xiaomi Phone app on the device. Confirm that an incoming call record from the configured contact appears in the recent calls list.