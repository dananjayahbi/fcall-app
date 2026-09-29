import 'package:flutter/material.dart';

import '../../../core/models/caller_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'caller_avatar.dart';

/// Module 4: the top half of the incoming-call screen.
///
/// Order matters and matches the real dialer: identity, then the number, then
/// the status line. "Incoming call" sits *above* the name in HyperOS, so it is
/// rendered first.
class CallerHeader extends StatelessWidget {
  const CallerHeader({required this.profile, super.key, this.animating = true});

  final CallerProfile profile;
  final bool animating;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          'Incoming call',
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.82),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        CallerAvatar(profile: profile, animating: animating),
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            profile.displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
        ),
        if (profile.hasNumber) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            profile.number,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 19,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _SimChip(label: profile.simLabel),
      ],
    );
  }
}

class _SimChip extends StatelessWidget {
  const _SimChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.sim_card_outlined, size: 12, color: Colors.white70),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
