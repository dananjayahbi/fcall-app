import 'package:flutter/material.dart';

import '../../../core/models/permission_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// One row of the spec §5 setup matrix: state, why it matters, and the exact
/// HyperOS navigation path.
class PermissionRow extends StatelessWidget {
  const PermissionRow({
    required this.requirement,
    required this.granted,
    required this.onOpen,
    super.key,
  });

  final PermissionRequirement requirement;
  final bool granted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: granted
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                granted ? Icons.check_circle : Icons.error_outline,
                size: 18,
                color: granted ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  requirement.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            requirement.why,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    requirement.hyperOsPath,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('Open ${requirement.hyperOsLabel}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
