import 'package:flutter/material.dart';

/// HyperOS / MIUI dark palette tokens tuned for the incoming-call clone.
///
/// The call screens are the visual centrepiece of this app, so the palette is
/// built around the two things a real dialer gets right: a very dark, slightly
/// blue-shifted background (so the display is easy on the eyes at 2am) and two
/// saturated, unmistakable action colours that read correctly at a glance.
abstract final class AppColors {
  // Base surfaces
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141A21);
  static const Color surfaceElevated = Color(0xFF1C242D);
  static const Color surfaceOverlay = Color(0xFF232D38);

  // Hairlines / dividers
  static const Color divider = Color(0x14FFFFFF);
  static const Color border = Color(0x1FFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF2F6FA);
  static const Color textSecondary = Color(0xFFA8B6C4);
  static const Color textTertiary = Color(0xFF6C7C8C);

  // Brand / primary action
  static const Color primary = Color(0xFF2E7CF6);
  static const Color primaryPressed = Color(0xFF1E62D6);
  static const Color primaryMuted = Color(0x332E7CF6);

  // Call actions — HyperOS green answer / red decline
  static const Color answer = Color(0xFF22C55E);
  static const Color answerPressed = Color(0xFF16A34A);
  static const Color decline = Color(0xFFEF4444);
  static const Color declinePressed = Color(0xFFDC2626);

  // Status accents
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);

  // Ringtone / vibration indicator
  static const Color ringtoneWave = Color(0xFF60A5FA);

  // Simulation badge (never let a web run be mistaken for a device run)
  static const Color inspect = Color(0xFF7C3AED);
  static const Color inspectSurface = Color(0x1F7C3AED);

  /// Vertical gradient used behind the call screens.
  static const LinearGradient callBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF16202B),
      Color(0xFF0B0F14),
      Color(0xFF07090C),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// Gradient for the primary CTA.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF3B82F6), Color(0xFF2563EB)],
  );

  /// Radial glow placed behind the caller avatar on the incoming-call screen.
  static const LinearGradient avatarGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF4C8DFF), Color(0xFF2E5FD6)],
  );
}
