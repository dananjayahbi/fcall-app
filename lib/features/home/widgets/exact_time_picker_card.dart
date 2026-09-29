import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../widgets/glass_card.dart';

/// Module 1: exact wall-clock appointment.
///
/// Defaults to one minute out rather than "now", because an exact trigger whose
/// time has already passed is rejected by the scheduler and the user would be
/// left staring at an error with no obvious cause.
class ExactTimePickerCard extends StatefulWidget {
  const ExactTimePickerCard({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<ExactTimePickerCard> createState() => _ExactTimePickerCardState();
}

class _ExactTimePickerCardState extends State<ExactTimePickerCard> {
  /// The value currently held by the pickers — kept separate from the widget
  /// input so picking a date and then a time in the same session does not have
  /// one overwrite the other.
  late DateTime _draft = _safeInitial(widget.value);

  DateTime _safeInitial(DateTime value) =>
      value.isAfter(DateTime.now())
      ? value
      : DateTime.now().add(const Duration(minutes: 1));

  @override
  void didUpdateWidget(ExactTimePickerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _draft = _safeInitial(widget.value);
    }
  }

  void _emit(DateTime next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_draft),
      builder: (BuildContext ctx, Widget? child) => _themed(ctx, child),
    );
    if (picked == null || !mounted) return;
    _emit(
      DateTime(
        _draft.year,
        _draft.month,
        _draft.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _draft,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      builder: (BuildContext ctx, Widget? child) => _themed(ctx, child),
    );
    if (picked == null || !mounted) return;
    _emit(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        _draft.hour,
        _draft.minute,
      ),
    );
  }

  Widget _themed(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
      ),
      child: child!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = _draft.difference(DateTime.now());
    final bool invalid = remaining.isNegative;

    return GlassCard(
      accent: invalid ? AppColors.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _PickerButton(
                  icon: Icons.event_outlined,
                  label: 'Date',
                  value: TimeFormatter.relativeDay(_draft),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _PickerButton(
                  icon: Icons.access_time,
                  label: 'Time',
                  value: TimeFormatter.clockTime(_draft),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Icon(
                invalid ? Icons.error_outline : Icons.info_outline,
                size: 15,
                color: invalid ? AppColors.danger : AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  invalid
                      ? 'That moment has already passed.'
                      : 'Rings in ${TimeFormatter.countdown(remaining)}'
                            ' • ${TimeFormatter.exactDateTime(_draft)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: invalid ? AppColors.danger : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceOverlay,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
