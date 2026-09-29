import 'package:flutter/material.dart';

import '../../../core/models/caller_profile.dart';
import '../../../core/theme/app_spacing.dart';

/// The contact circle on the incoming-call screen.
///
/// The breathing halo is driven by an explicit [AnimationController] rather
/// than an implicit animation so it can be paused the moment the call is
/// answered — a running animation across a screen swap is a classic leak.
class CallerAvatar extends StatefulWidget {
  const CallerAvatar({required this.profile, super.key, this.animating = true});

  final CallerProfile profile;
  final bool animating;

  @override
  State<CallerAvatar> createState() => _CallerAvatarState();
}

class _CallerAvatarState extends State<CallerAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(CallerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.animating && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CallerProfile profile = widget.profile;
    final Color base = HSLColor.fromAHSL(1, profile.avatarHue, 0.5, 0.42).toColor();

    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double t = _pulse.value;
        return Container(
          height: AppSizes.callerAvatarSize,
          width: AppSizes.callerAvatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: base.withValues(alpha: 0.20 + 0.20 * t),
                blurRadius: 28 + 26 * t,
                spreadRadius: 2 + 8 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(base, Colors.white, 0.22)!,
              Color.lerp(base, Colors.black, 0.26)!,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        alignment: Alignment.center,
        child: Text(
          profile.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
