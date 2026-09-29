/// A single permission / OS setting the user must enable, per spec §5.
class PermissionRequirement {
  const PermissionRequirement({
    required this.id,
    required this.title,
    required this.why,
    required this.hyperOsPath,
    required this.hyperOsLabel,
  });

  final String id;
  final String title;

  /// Why it is required — shown in the UI so the user is not asked blindly.
  final String why;

  /// The literal HyperOS navigation path, rendered verbatim so the user can
  /// follow it on the handset.
  final String hyperOsPath;
  final String hyperOsLabel;
}

/// Spec §5 device configuration matrix, as data.
///
/// Lives in `core/models` (not a screen) so the setup guide, the home banner
/// and the bridge all read the same list and cannot drift.
abstract final class PermissionMatrix {
  static const List<PermissionRequirement> all = <PermissionRequirement>[
    PermissionRequirement(
      id: 'popupWindows',
      title: 'Display pop-up windows in background',
      why:
          'HyperOS blocks background activities from drawing over other apps '
          'by default. Without this the alarm fires but the call screen never '
          'appears.',
      hyperOsPath:
          'Settings > Apps > Permissions > Other permissions > Incoming Call > '
          'Display pop-up windows while running in the background',
      hyperOsLabel: 'Display pop-up windows',
    ),
    PermissionRequirement(
      id: 'autostart',
      title: 'Autostart',
      why:
          'HyperOS kills background workers that are not whitelisted. Autostart '
          'keeps the alarm service alive after the screen turns off.',
      hyperOsPath: 'Settings > Apps > Manage apps > Incoming Call > Autostart > On',
      hyperOsLabel: 'Autostart',
    ),
    PermissionRequirement(
      id: 'batterySaver',
      title: 'Battery saver — no restrictions',
      why:
          'The default "Battery saver: Optimise background" setting kills the '
          'alarm timer as soon as the screen goes off.',
      hyperOsPath:
          'Settings > Apps > Manage apps > Incoming Call > Battery saver > '
          'No restrictions',
      hyperOsLabel: 'No restrictions',
    ),
    PermissionRequirement(
      id: 'exactAlarm',
      title: 'Alarms & reminders',
      why:
          'Android 13+ requires explicit user consent before an app can schedule '
          'an exact alarm that still fires through Doze.',
      hyperOsPath:
          'Settings > Apps > Permissions > Other permissions > Incoming Call > '
          'Alarms & reminders > Allow',
      hyperOsLabel: 'Alarms & reminders',
    ),
    PermissionRequirement(
      id: 'notifications',
      title: 'Notifications',
      why:
          'When the device is already unlocked the call is presented as a '
          'high-priority heads-up notification instead of a full screen takeover.',
      hyperOsPath:
          'Settings > Apps > Manage apps > Incoming Call > Notifications > On',
      hyperOsLabel: 'Notifications',
    ),
  ];
}

/// Live state of every entry in [PermissionMatrix].
class PermissionStatus {
  const PermissionStatus({this.granted = const <String, bool>{}});

  final Map<String, bool> granted;

  bool isGranted(String id) => granted[id] ?? false;

  List<PermissionRequirement> get missing {
    if (PermissionMatrix.all.every((PermissionRequirement r) => isGranted(r.id))) {
      return const <PermissionRequirement>[];
    }
    return PermissionMatrix.all
        .where((PermissionRequirement r) => !isGranted(r.id))
        .toList(growable: false);
  }

  int get grantedCount =>
      PermissionMatrix.all.where((PermissionRequirement r) => isGranted(r.id)).length;

  int get totalCount => PermissionMatrix.all.length;

  bool get allGranted => missing.isEmpty;

  PermissionStatus copyWith(Map<String, bool> next) {
    return PermissionStatus(granted: Map<String, bool>.unmodifiable(next));
  }

  /// The browser cannot answer these questions, so the preview bridge
  /// reports them as granted. On Android the values are read from the OS.
  static const PermissionStatus assumeAllGranted = PermissionStatus(
    granted: <String, bool>{
      'popupWindows': true,
      'autostart': true,
      'batterySaver': true,
      'exactAlarm': true,
      'notifications': true,
    },
  );
}
