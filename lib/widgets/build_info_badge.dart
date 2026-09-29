import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../services/platform/platform_bridge.dart';

/// Environment readout for the **hidden** diagnostics screen.
///
/// This deliberately has no counterpart on any user-facing screen. The
/// incoming-call UI has to be indistinguishable from a real call, so nothing
/// that describes the app's internals may appear on a screen a bystander can
/// see. The same information is still needed when diagnosing "the call did not
/// arrive", so it lives here, reachable only from the diagnostics route.
///
/// The bridge is read from [AppScope] rather than a global so a widget test
/// reports the injected bridge's kind, not the ambient one.
class BuildInfoBadge extends StatelessWidget {
  const BuildInfoBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final PlatformBridge bridge = AppScope.of(context).bridge;
    final bool onDevice = bridge.isHardwareBacked;
    final String label = onDevice
        ? 'Device'
        : switch (bridge.kind) {
            PlatformKind.webPreview => 'Web preview',
            PlatformKind.headless => 'Headless',
            PlatformKind.android => 'Device',
          };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
        vertical: compact ? AppSpacing.xs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: onDevice ? AppColors.primaryMuted : AppColors.inspectSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: onDevice ? AppColors.primary : AppColors.inspect,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            onDevice ? Icons.phone_android : Icons.developer_mode_outlined,
            size: compact ? 12 : 14,
            color: onDevice ? AppColors.info : AppColors.inspect,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: onDevice ? AppColors.info : AppColors.inspect,
            ),
          ),
        ],
      ),
    );
  }
}
