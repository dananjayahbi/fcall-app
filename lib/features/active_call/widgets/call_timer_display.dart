import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_formatter.dart';

/// Module 5 / Phase 4.2: the `00:00 ->` call timer.
///
/// The digits use tabular figures so the layout does not jitter every second as
/// the glyph widths change.
class CallTimerDisplay extends StatelessWidget {
  const CallTimerDisplay({required this.seconds, super.key});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          TimeFormatter.callTimer(seconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
            height: 1.1,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'In call',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
