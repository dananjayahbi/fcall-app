import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Module 5 / Phase 4.3: the red termination button.
///
/// Guarded by a confirm sheet rather than firing immediately. A single mis-tap
/// on a full-screen target ends the call and, with it, the proximity lock and
/// the call-log write — an easy mistake to make one-handed.
class EndCallButton extends StatelessWidget {
  const EndCallButton({required this.onEnd, super.key});

  final Future<void> Function() onEnd;

  Future<void> _confirm(BuildContext context) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'End this call?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'The proximity lock is released, audio returns to normal and '
                'the call is written to your call history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(false),
                      child: const Text('Stay on call'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.decline,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('End call'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await onEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => _confirm(context),
          child: Container(
            height: AppSizes.endCallSize,
            width: AppSizes.endCallSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.decline,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.decline.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.call_end, size: 30, color: Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'End call',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
