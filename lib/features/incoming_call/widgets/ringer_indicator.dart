import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../services/ringer/ringer_service.dart';

/// Module 4: the animated waveform that shows the ringtone is playing.
///
/// A real ring indicator is a *state* readout, so it reads from [RingerState]
/// rather than assuming "ringing == visible". That is what makes the
/// volume-key silence visible to the user, matching a real handset where the
/// sound stops but the call screen stays.
class RingerIndicator extends StatefulWidget {
  const RingerIndicator({required this.state, super.key});

  final RingerState state;

  @override
  State<RingerIndicator> createState() => _RingerIndicatorState();
}

class _RingerIndicatorState extends State<RingerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(RingerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.state.active) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.state.active;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 34,
          width: 120,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List<Widget>.generate(5, (int index) {
                  final double phase =
                      (_controller.value + index * 0.2) % 1.0;
                  final double wave = active
                      ? (0.25 + 0.75 * _triangle(phase))
                      : 0.18;
                  return Container(
                    width: 4,
                    height: 8 + 26 * wave,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.ringtoneWave
                          : AppColors.textTertiary.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          active
              ? 'Ringing'
              : widget.state.silenced
              ? 'Ringer silenced — call still incoming'
              : 'Silent',
          style: TextStyle(
            color: active
                ? AppColors.ringtoneWave
                : widget.state.silenced
                ? AppColors.warning
                : AppColors.textTertiary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        if (widget.state.vibrating && active) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.vibration, size: 12, color: AppColors.textTertiary),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Vibrating',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 0..1 triangular wave — the shape a real ringtone envelope produces.
  double _triangle(double t) {
    final double x = t * 2;
    return x < 1 ? x : 2 - x;
  }
}
