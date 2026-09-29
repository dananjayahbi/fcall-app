/// Browser implementation of the host hooks used by the web bridge.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

void installKeyboardListener(void Function(String key) onVolumeKey) {
  web.window.addEventListener(
    'keydown',
    ((web.Event event) {
      final web.KeyboardEvent keyboard = event as web.KeyboardEvent;
      final String key = keyboard.key;
      // Arrow keys stand in for the physical volume keys; F5 stands in for the
      // quick-action tile. All three route into the same `RingerService`
      // entry point the Android build uses.
      if (key == 'ArrowDown' || key == 'ArrowUp' || key == 'F5') {
        onVolumeKey(key);
      }
    }).toJS,
  );
}

void stopVibration() {
  // navigator.vibrate(0) is the documented way to cancel a running pattern.
  web.window.navigator.vibrate(0.toJS);
}

void vibratePattern(List<int> pattern) {
  final List<JSNumber> values = <JSNumber>[
    for (final int value in pattern) value.toJS,
  ];
  web.window.navigator.vibrate(values.toJS);
}

Future<bool> requestNotificationPermission() async {
  if (!web.window.isSecureContext) {
    return false;
  }
  final String result =
      (await web.Notification.requestPermission().toDart).toDart;
  return result == 'granted';
}

void showBrowserNotification({required String title, required String body}) {
  if (web.Notification.permission != 'granted') {
    return;
  }
  web.Notification(
    title,
    web.NotificationOptions(body: body, tag: 'incoming-call', silent: false),
  );
}

bool get isBrowser => true;
