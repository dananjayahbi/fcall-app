/// Non-web implementation of the browser host hooks.
///
/// Every function is a no-op so the same call site compiles for Android.
library;

/// Installs the volume-key style keyboard listener. No-op off the web.
void installKeyboardListener(void Function(String key) onVolumeKey) {}

/// Cancels any running vibration pattern. No-op off the web.
void stopVibration() {}

/// Runs a single vibration pattern via the Vibration API. No-op off the web.
void vibratePattern(List<int> pattern) {}

/// Requests browser notification permission. Resolves to `false` off the web.
Future<bool> requestNotificationPermission() async => false;

/// Shows a browser notification if permission was granted. No-op off the web.
void showBrowserNotification({
  required String title,
  required String body,
}) {}

/// True when running inside a browser document.
bool get isBrowser => false;
