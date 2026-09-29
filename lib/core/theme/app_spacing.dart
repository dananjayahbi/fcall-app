/// Spacing, radius and sizing scale.
///
/// Every hard-coded number in the UI comes from here so the call screens can be
/// tuned for a 6.7" Redmi 14C panel (1080 x 2400, ~20:9) from one file.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  static const double gapTiny = 4;
  static const double gapSmall = 8;
  static const double gap = 12;
  static const double gapMedium = 20;
  static const double gapLarge = 28;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

abstract final class AppSizes {
  /// Standard interactive control height on the config screen.
  static const double controlHeight = 52;

  /// Diameter of the large answer / decline buttons.
  static const double callActionSize = 76;

  /// Diameter of the end-call button.
  static const double endCallSize = 68;

  /// Diameter of a single in-call control (mute / keypad / speaker).
  static const double callControlSize = 62;

  /// Caller avatar on the incoming-call screen.
  static const double callerAvatarSize = 132;
}
