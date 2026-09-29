import 'package:flutter/material.dart';

import '../../../core/models/permission_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Spec §5: the setup reminder.
///
/// Shown only while something is actually missing, and worded as a neutral
/// "finish setup" nudge. When every item is granted it renders nothing at all,
/// so a correctly configured install shows no banner whatsoever.
///
/// The copy deliberately avoids naming the app's purpose: a notification that
/// says "set this up so calls can appear" on the lock screen is a bigger tell
/// than the app itself.
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({
    required this.status,
    required this.onOpen,
    super.key,
    this.hardwareBacked = true,
  });

  final PermissionStatus status;
  final VoidCallback onOpen;
  final bool hardwareBacked;

  @override
  Widget build(BuildContext context) {
    // A non-device build has nothing the user can grant, so the banner is
    // meaningless there — and showing it would be the only thing on screen
    // hinting at the difference.
    if (!hardwareBacked || status.allGranted) {
      return const SizedBox.shrink();
    }

    final List<PermissionRequirement> missing = status.missing;
    final String headline = 'Finish setup';
    final String body = '${missing.length} '
        '${missing.length == 1 ? 'item needs' : 'items need'} attention before '
        'alerts can be delivered reliably: '
        '${missing.map((PermissionRequirement r) => r.hyperOsLabel).join(', ')}.';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 21,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  headline,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: onOpen,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Review setup',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.warning),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
