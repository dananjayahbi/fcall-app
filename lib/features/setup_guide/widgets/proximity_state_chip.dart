import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Module 5: reports what the proximity sensor is reading and what the screen
/// policy is doing about it.
///
/// The distinction between NEAR and "screen off" is the point: the sensor reading
/// is a *measurement*, the screen state is a *consequence*, and on Android the
/// second is produced by the hardware wake lock rather than by this widget.
class ProximityStateChip extends StatelessWidget {
  const ProximityStateChip({required this.isNear, super.key});

  final bool isNear;

  @override
  Widget build(BuildContext context) {
    final Color accent = isNear ? AppColors.warning : AppColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isNear ? Icons.sensors : Icons.sensors_off,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isNear
                ? 'Proximity NEAR — display wake lock held'
                : 'Proximity FAR — display on',
            style: TextStyle(
              color: accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
