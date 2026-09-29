import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Module 4: the answer / decline targets.
///
/// HyperOS on the Redmi 14C ships the horizontal dual-button layout, so that
/// is what is rendered here. A vertical swipe model is deliberately **not**
/// offered: a swipe-only target is undiscoverable and, more importantly, cannot
/// be operated one-handed with the phone ringing, which is the exact situation
/// this screen is designed for.
class AnswerDeclineBar extends StatelessWidget {
  const AnswerDeclineBar({
    required this.onAnswer,
    required this.onDecline,
    super.key,
    this.answerEnabled = true,
  });

  final VoidCallback onAnswer;
  final VoidCallback onDecline;
  final bool answerEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _CallAction(
          key: const ValueKey<String>('decline-action'),
          icon: Icons.call_end,
          color: AppColors.decline,
          pressedColor: AppColors.declinePressed,
          label: 'Decline',
          onTap: onDecline,
        ),
        _CallAction(
          key: const ValueKey<String>('answer-action'),
          icon: Icons.call,
          color: AppColors.answer,
          pressedColor: AppColors.answerPressed,
          label: 'Answer',
          onTap: answerEnabled ? onAnswer : null,
        ),
      ],
    );
  }
}

class _CallAction extends StatefulWidget {
  const _CallAction({
    super.key,
    required this.icon,
    required this.color,
    required this.pressedColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color pressedColor;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_CallAction> createState() => _CallActionState();
}

class _CallActionState extends State<_CallAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color color = _pressed ? widget.pressedColor : widget.color;

    // The tap target is the whole button (icon + label), not just the circle.
    // A 76px circle with a label underneath is a 100px-tall target; a user
    // aiming at the label gets nothing, which on a ringing screen is fatal.
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
        GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onTap,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              height: AppSizes.callActionSize,
              width: AppSizes.callActionSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: _pressed ? 0.15 : 0.42),
                    blurRadius: _pressed ? 6 : 20,
                    spreadRadius: _pressed ? 0 : 2,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
