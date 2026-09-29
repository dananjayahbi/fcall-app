import 'package:flutter/material.dart';

import '../../../core/models/call_trigger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/section_header.dart';

/// Module 1 / Phase 4.1: the 15s / 30s / 1m / 5m preset row.
class DelayPresetRow extends StatelessWidget {
  const DelayPresetRow({
    required this.selected,
    required this.onSelect,
    required this.onCustom,
    super.key,
    this.customActive = false,
    this.customLabel = 'Custom',
  });

  /// The preset duration currently chosen, or `null` for the custom option.
  final Duration? selected;
  final ValueChanged<Duration> onSelect;
  final VoidCallback onCustom;

  /// True when the exact-time picker is the active choice.
  final bool customActive;
  final String customLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader('When should it ring?'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ...CallTriggerPresets.all.map((CallTriggerOption option) {
              final bool isSelected = selected == option.duration;
              return _PresetChip(
                label: option.label,
                selected: isSelected,
                onTap: () => onSelect(option.duration),
              );
            }),
            _PresetChip(
              label: customLabel,
              selected: customActive,
              onTap: onCustom,
              icon: Icons.schedule,
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryMuted : AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
