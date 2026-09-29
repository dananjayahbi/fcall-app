import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/utils/time_formatter.dart';

/// Live "rings in mm:ss" indicator shown while an alarm is armed.
class CountdownChip extends StatefulWidget {
  const CountdownChip({required this.fireAt, super.key, this.onCancel});

  final DateTime fireAt;
  final VoidCallback? onCancel;

  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  late final Stream<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: _ticker,
      builder: (BuildContext context, AsyncSnapshot<void> _) {
        final Duration remaining = widget.fireAt.difference(DateTime.now());
        final bool imminent = remaining.inSeconds <= 10 && !remaining.isNegative;
        final bool fired = remaining.isNegative;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: fired
                ? AppColors.primaryMuted
                : imminent
                ? AppColors.danger.withValues(alpha: 0.14)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: fired
                  ? AppColors.primary
                  : imminent
                  ? AppColors.danger
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                fired ? Icons.notifications_active : Icons.timer_outlined,
                size: 18,
                color: fired
                    ? AppColors.primary
                    : imminent
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  fired
                      ? 'Ringing now'
                      : 'Incoming call in ${TimeFormatter.countdown(remaining)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fired
                        ? AppColors.textPrimary
                        : imminent
                        ? AppColors.danger
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
            ],
          ),
        );
      },
    );
  }
}
