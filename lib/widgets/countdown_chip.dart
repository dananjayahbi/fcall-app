import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/time_formatter.dart';

/// Live "rings in mm:ss" indicator shown while an alarm is armed.
///
/// ## Why this takes a `completed` flag
///
/// The chip previously inferred "the call has arrived" purely from the clock
/// running past the fire time, and kept saying **Ringing now** forever after —
/// including after the user declined. Two different things are conflated:
///
///  * the fire time has passed, and
///  * a call is *currently* ringing.
///
/// Only the first is knowable from [fireAt]. A declined call leaves this chip
/// mounted for as long as the parent keeps the schedule row alive, so the screen
/// claimed a call was ringing when it had already been rejected and logged. The
/// parent now states what actually happened and the chip reports that, rather
/// than the chip guessing from a clock.
class CountdownChip extends StatefulWidget {
  const CountdownChip({
    required this.fireAt,
    super.key,
    this.onCancel,
    this.completed = false,
    this.completedLabel = 'Call ended',
  });

  final DateTime fireAt;
  final VoidCallback? onCancel;

  /// True once the call this chip was counting down to has been handled —
  /// answered, declined or missed.
  final bool completed;

  /// Rendered when [completed], so a declined call does not read as "missed".
  final String completedLabel;

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  late final Stream<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  );

  @override
  Widget build(BuildContext context) {
    // Terminal state short-circuits the ticker entirely: there is no countdown
    // left to animate, and continuing to tick would keep implying a live call.
    if (widget.completed) {
      return _shell(
        colour: AppColors.surfaceElevated,
        borderColour: AppColors.border,
        icon: Icons.check_circle_outline,
        iconColour: AppColors.textSecondary,
        message: widget.completedLabel,
        cancelLabel: 'Dismiss',
      );
    }

    return StreamBuilder<void>(
      stream: _ticker,
      builder: (BuildContext context, AsyncSnapshot<void> _) {
        final Duration remaining = widget.fireAt.difference(DateTime.now());
        final bool imminent = remaining.inSeconds <= 10 && !remaining.isNegative;
        final bool fired = remaining.isNegative;
        return _shell(
          colour: fired
              ? AppColors.primaryMuted
              : imminent
              ? AppColors.danger.withValues(alpha: 0.14)
              : AppColors.surfaceElevated,
          borderColour: fired
              ? AppColors.primary
              : imminent
              ? AppColors.danger
              : AppColors.border,
          icon: fired ? Icons.notifications_active : Icons.timer_outlined,
          iconColour: fired
              ? AppColors.primary
              : imminent
              ? AppColors.danger
              : AppColors.textSecondary,
          message: fired
              ? 'Ringing now'
              : 'Incoming call in ${TimeFormatter.countdown(remaining)}',
          cancelLabel: 'Cancel',
        );
      },
    );
  }

  Widget _shell({
    required Color colour,
    required Color borderColour,
    required IconData icon,
    required Color iconColour,
    required String message,
    required String cancelLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColour),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: iconColour),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (widget.onCancel != null)
            TextButton(
              onPressed: widget.onCancel,
              child: Text(cancelLabel),
            ),
        ],
      ),
    );
  }
}
