import 'package:flutter/material.dart';

import '../../../core/models/call_outcome.dart';
import '../../../core/models/call_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_formatter.dart';

/// One row of the call log.
///
/// The three outcomes are visually distinct, because "Missed" and "Rejected" are
/// not interchangeable in an Android call log: a missed call is red, a rejected
/// incoming call is not.
class CallLogTile extends StatelessWidget {
  const CallLogTile({required this.entry, super.key, this.highlight = false});

  final SimCallLogEntry entry;

  /// Set when the row was just written, so a freshly logged call is findable.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final (Color accent, IconData icon, String label) = switch (entry.resolution) {
      CallResolution.answered => (AppColors.success, Icons.call_received, 'Incoming'),
      CallResolution.missed => (AppColors.danger, Icons.call_missed, 'Missed'),
      CallResolution.declined => (AppColors.textSecondary, Icons.call_made, 'Rejected'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: highlight ? accent.withValues(alpha: 0.10) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlight ? accent.withValues(alpha: 0.45) : AppColors.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.cachedName.isEmpty ? 'Unknown' : entry.cachedName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.number}  •  $label',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                TimeFormatter.clockTime(entry.startedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.durationLabel,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
