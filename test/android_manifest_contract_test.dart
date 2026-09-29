import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Module 2 — the native manifest contract, verified statically.
///
/// ## Why this file exists
///
/// The exact alarm was delivered to `alarm.CallAlarmReceiver`, while the
/// manifest declared `receiver.CallAlarmReceiverAlias`. An explicit `Intent`
/// naming a component that is not declared is **never delivered** — the alarm
/// fired and vanished, so "Quick trigger" armed successfully and the ring
/// screen never appeared. The build was green, every Dart test passed, and the
/// defect lived entirely in a file no Dart test reads.
///
/// The same class of bug applies to every action string and channel name in
/// this project, because they are duplicated across the language boundary and
/// agree only by convention. These tests read the real files on disk and
/// compare, so a rename on one side fails here instead of on a handset.
///
/// They are deliberately file-based rather than runtime-based: a runtime check
/// would need a real device, and a defect that only reproduces on hardware is
/// exactly the one worth catching in CI.
void main() {
  final File manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  );
  final File scheduler = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/alarm/CallAlarmScheduler.kt',
  );
  final File mainActivity = File(
    'android/app/src/main/kotlin/com/mobiletel/incomingcall/MainActivity.kt',
  );
  final File bridgeService = File(
    'lib/services/platform/bridge_service.dart',
  );

  group('the alarm receiver the scheduler targets is declared', () {
    test('the PendingIntent component exists in the manifest', () {
      final String kotlin = scheduler.readAsStringSync();
      final String xml = manifest.readAsStringSync();

      // The class the PendingIntent is built against.
      final RegExpMatch? target = RegExp(
        r'val intent = Intent\(context,\s*([A-Za-z0-9_.]+)::class\.java\)',
      ).firstMatch(kotlin);
      expect(
        target,
        isNotNull,
        reason: 'Could not find the PendingIntent target in CallAlarmScheduler.kt',
      );
      final String simpleName = target!.group(1)!;
      final String fqcn = 'com.mobiletel.incomingcall.alarm.$simpleName';

      // The manifest may declare the component relatively (".alarm.Foo") or
      // absolutely, so both spellings are accepted rather than assuming one.
      final String relative = '.alarm.$simpleName';
      expect(
        xml.contains('android:name="$fqcn"') || xml.contains('android:name="$relative"'),
        isTrue,
        reason:
            'CallAlarmScheduler targets $fqcn but AndroidManifest.xml does not '
            'declare it. An explicit Intent to an undeclared component is never '
            'delivered, so the alarm fires into a void.',
      );
    });

    test('the declared receiver has the alarm action as an intent-filter', () {
      final String xml = manifest.readAsStringSync();
      final String action = RegExp(
        r'ACTION_CALL_ALARM\s*=\s*"([^"]+)"',
      ).firstMatch(scheduler.readAsStringSync())!.group(1)!;

      expect(
        xml,
        contains('android:name="$action"'),
        reason: 'The alarm action must be declared as an intent-filter, not just '
            'used as a constant — an action nobody filters for never arrives.',
      );
    });
  });

  group('Dart and native agree on the channel names', () {
    test('the launch EventChannel is registered on the same name', () {
      final String dart = bridgeService.readAsStringSync();
      final String kotlin = mainActivity.readAsStringSync();

      // Scoped to the launch-channel constant specifically: the first
      // EventChannel literal in the file is the proximity channel, and
      // comparing that would pass while the launch one is wrong.
      // The name is on the *next* line, so the pattern spans newlines.
      final RegExpMatch? dartChannel = RegExp(
        r"_launchChannel\s*=\s*EventChannel\(\s*'([^']+)'",
      ).firstMatch(dart);
      expect(dartChannel, isNotNull, reason: 'No launch EventChannel found in Dart');

      final String channel = dartChannel!.group(1)!;
      final RegExpMatch? nativeChannel = RegExp(
        r'CHANNEL_LAUNCH\s*=\s*"(com\.mobiletel\.incomingcall/[^"]+)"',
      ).firstMatch(kotlin);

      expect(
        nativeChannel,
        isNotNull,
        reason:
            'Dart listens on $channel but MainActivity declares no '
            'CHANNEL_LAUNCH. The stream never produces an event, so a call '
            'fires with no ring screen.',
      );
      expect(
        nativeChannel!.group(1),
        channel,
        reason: 'Launch channel name mismatch between Dart and Kotlin.',
      );
    });
  });

  group('the reboot action is one the platform actually sends', () {
    test('BOOT_COMPLETED is filtered, not a custom action', () {
      final String xml = manifest.readAsStringSync();
      expect(
        xml,
        contains('android.intent.action.BOOT_COMPLETED'),
        reason:
            'The manifest filtered a custom "*.action.BOOT" string that nothing '
            'ever broadcasts, so a pending call was silently lost on reboot.',
      );
      expect(
        xml,
        isNot(contains('"com.mobiletel.incomingcall.action.BOOT"')),
        reason: 'A custom BOOT action is dead weight and misleads readers.',
      );
    });
  });

  group('the launch event discriminator is the same on both sides', () {
    test('consumeLaunchIntent returns the key the consumers test for', () {
      // `HomePage` gates on `launch['event'] == 'quickRing'` and
      // `LaunchDispatcher` switches on the same string. Returning a different
      // key drops the quick trigger silently.
      final String bridge = File(
        'android/app/src/main/kotlin/com/mobiletel/incomingcall/platform/AndroidBridgeImpl.kt',
      ).readAsStringSync();
      final RegExpMatch? returned = RegExp(
        r'return mapOf\(\s*"event" to LaunchSignalRelay\.Event\.QUICK_RING',
      ).firstMatch(bridge);
      expect(
        returned,
        isNotNull,
        reason:
            'consumeLaunchIntent must return the "event" key. Anything else is '
            'ignored by both the home screen and the dispatcher.',
      );

      final String home = File(
        'lib/features/home/home_page.dart',
      ).readAsStringSync();
      expect(home, contains("'quickRing'"));
    });

    test('the relay event names match the dispatcher constants', () {
      final String relay = File(
        'android/app/src/main/kotlin/com/mobiletel/incomingcall/platform/LaunchSignalRelay.kt',
      ).readAsStringSync();
      final String dispatcher = File(
        'lib/services/launch_dispatcher.dart',
      ).readAsStringSync();

      const Map<String, String> expected = <String, String>{
        'CALL_INCOMING': 'callIncoming',
        'QUICK_RING': 'quickRing',
      };
      // The volume key is Dart-only today (MainActivity invokes the method
      // channel directly), so it is checked on the Dart side alone.
      expect(dispatcher, contains("'volumeKeyPressed'"));

      expected.forEach((String kotlinName, String dartName) {
        expect(
          relay,
          contains('"$dartName"'),
          reason: 'LaunchSignalRelay is missing the $dartName literal.',
        );
        expect(
          dispatcher,
          contains("'$dartName'"),
          reason: 'LaunchDispatcher is missing the $dartName constant.',
        );
      });
    });
  });

  group('the ringer has exactly one owner', () {
    test('no component constructs a RingerController directly', () {
      final Directory kotlinRoot = Directory(
        'android/app/src/main/kotlin/com/mobiletel/incomingcall',
      );
      final List<File> files = kotlinRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.kt'))
          .toList();

      final List<String> offenders = <String>[];
      for (final File file in files) {
        final String name = file.path.split(Platform.pathSeparator).last;
        // RingerHub is the single allowed owner; it must be the only
        // construction site, or two ringers play at once and answering the
        // call leaves one of them sounding. The declaration in
        // RingerController.kt itself is not a construction.
        if (name == 'RingerHub.kt' || name == 'RingerController.kt') continue;
        if (RegExp(r'RingerController\(').hasMatch(file.readAsStringSync())) {
          offenders.add(name);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These files construct a RingerController directly instead of going '
            'through RingerHub: $offenders',
      );
    });
  });
}
