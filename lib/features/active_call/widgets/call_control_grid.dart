import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../active_call_controller.dart';

/// Module 5 / Phase 4.2: the Mute / Keypad / Speaker / Add-call grid.
///
/// Every button toggles a visual state only. Silence is a hard requirement, so
/// none of these are wired to any audio path.
class CallControlGrid extends StatelessWidget {
  const CallControlGrid({
    required this.controller,
    required this.onKeypad,
    super.key,
  });

  final ActiveCallController controller;
  final VoidCallback onKeypad;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _ControlButton(
          icon: controller.isActive(CallControl.mute)
              ? Icons.mic_off
              : Icons.mic_none,
          label: 'Mute',
          active: controller.isActive(CallControl.mute),
          onTap: () => controller.toggle(CallControl.mute),
        ),
        _ControlButton(
          icon: Icons.dialpad,
          label: 'Keypad',
          active: controller.isActive(CallControl.keypad),
          onTap: onKeypad,
        ),
        _ControlButton(
          icon: controller.isActive(CallControl.speaker)
              ? Icons.volume_up
              : Icons.volume_down,
          label: 'Speaker',
          active: controller.isActive(CallControl.speaker),
          onTap: () => controller.toggle(CallControl.speaker),
        ),
        _ControlButton(
          icon: Icons.person_add_alt_1,
          label: 'Add call',
          active: controller.isActive(CallControl.addCall),
          onTap: () => controller.toggle(CallControl.addCall),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              height: AppSizes.callControlSize,
              width: AppSizes.callControlSize,
              child: Icon(
                icon,
                size: 24,
                color: active ? AppColors.background : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
