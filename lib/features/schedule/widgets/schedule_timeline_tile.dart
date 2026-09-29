import 'package:flutter/material.dart';

import '../../../core/models/scheduled_call.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/utils/timeline_gap_formatter.dart';

/// One armed call rendered as a point on a vertical time line.
///
/// ## Why the gap is rendered in a *shared* scale
///
/// Each row shows the distance from the previous one. Rendering every gap in
/// its own natural unit ("30s", "5m", "2h") makes the column ragged and forces
/// the eye to re-read the unit per row. The timeline computes one scale for the
/// whole list and passes it down, so the gaps are directly comparable — which
/// is the entire purpose of showing them.
///
/// A dot and a connecting line make it read as a timeline rather than a list,
/// and the line is drawn by the parent so it spans continuously between rows.
class ScheduleTimelineTile extends StatelessWidget {
  const ScheduleTimelineTile({
    required this.call,
    required this.scale,
    required this.gapFromPrevious,
    super.key,
    this.isFirst = false,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
  });

  final ScheduledCall call;
  final TimelineGapScale scale;

  /// Null for the first row — there is nothing before it to be a gap from.
  final Duration? gapFromPrevious;

  final bool isFirst;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final bool soon = call.timeRemaining().inMinutes < 5;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Rail(
            isFirst: isFirst,
            isLast: isLast,
            urgent: soon,
            gapLabel: gapFromPrevious == null
                ? null
                : TimelineGapFormatter.formatAt(gapFromPrevious!, scale),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Card(
              call: call,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dot, the connecting line, and the gap label.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.isFirst,
    required this.isLast,
    required this.urgent,
    this.gapLabel,
  });

  final bool isFirst;
  final bool isLast;
  final bool urgent;
  final String? gapLabel;

  @override
  Widget build(BuildContext context) {
    final Color dot = urgent ? AppColors.primary : AppColors.textTertiary;
    return SizedBox(
      width: 54,
      child: Column(
        children: <Widget>[
          // The gap sits above its dot, so it reads as "this much later than
          // the one above" — the same direction the eye travels down the list.
          SizedBox(
            height: 22,
            child: gapLabel == null
                ? null
                : Text(
                    gapLabel!,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(
            height: 20,
            child: isFirst
                ? null
                : const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              border: isLast ? null : Border.all(color: AppColors.background, width: 2),
            ),
          ),
          if (!isLast)
            const Expanded(
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.call, this.onEdit, this.onDelete});

  final ScheduledCall call;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  call.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (call.randomised)
                const Tooltip(
                  message: 'Chosen at random',
                  child: Icon(
                    Icons.casino_outlined,
                    size: 15,
                    color: AppColors.textTertiary,
                  ),
                ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Edit time',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Delete',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule,
                size: 13,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                TimeFormatter.clockTime(call.fireAt),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '  ·  ${TimeFormatter.relativeDay(call.fireAt)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            TimelineGapFormatter.until(call.fireAt),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: call.timeRemaining().inMinutes < 5
                  ? AppColors.primary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
