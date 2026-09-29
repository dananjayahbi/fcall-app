import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/call_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/logger.dart';
import '../../services/call_orchestrator.dart';
import 'active_call_controller.dart';
import 'widgets/call_control_grid.dart';
import 'widgets/call_timer_display.dart';
import 'widgets/end_call_button.dart';
import 'widgets/keypad_sheet.dart';

/// Module 5: the active-call screen.
///
/// Three things are load-bearing here and are worth stating plainly:
///
/// 1. **Silence.** No audio element of any kind is created. The mode is switched
///     to `MODE_IN_COMMUNICATION` natively so the OS treats the device as being
///     on a call, but nothing is ever played into it.
/// 2. **Proximity drives the display, not this widget.** `isNear` is rendered as
///     a state readout only; the actual panel-off is the hardware
///     `PROXIMITY_SCREEN_OFF_WAKE_LOCK` on the Android side.
/// 3. **Teardown is unconditional.** Every exit path — end button, system back,
///     app dispose — releases the wake lock, restores the audio mode and writes
///     the call log, so the phone can never be left holding a proximity lock.
class ActiveCallPage extends StatefulWidget {
  const ActiveCallPage({
    required this.session,
    required this.orchestrator,
    super.key,
  });

  final CallSession session;
  final CallOrchestrator orchestrator;

  @override
  State<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends State<ActiveCallPage> {
  late final ActiveCallController _controller;
  bool _cleanedUp = false;

  @override
  void initState() {
    super.initState();
    // The timer anchors on the moment of answer, not on when this widget
    // happened to build, so it stays correct across a rebuild or a restore.
    _controller = ActiveCallController(
      orchestrator: widget.orchestrator,
      answeredAt: widget.session.answeredAt ?? widget.session.startedAt,
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _hangUp() async {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _controller.resetControls();
    AppLogger.instance.info('active', 'end call tapped');
    await widget.orchestrator.hangUp();
  }

  void _openKeypad() {
    if (!_controller.isActive(CallControl.keypad)) {
      _controller.toggle(CallControl.keypad);
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext _) => const KeypadSheet(),
    ).whenComplete(() => _controller.toggle(CallControl.keypad));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _hangUp();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.callBackgroundGradient,
            ),
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    child: Column(
                      children: <Widget>[
                        const Spacer(flex: 2),
                        Text(
                          widget.session.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // The timer says "In call"; it does not narrate the
                        // sensor. On a real handset the display simply goes
                        // dark at the ear — announcing "proximity NEAR" on
                        // screen is exactly the kind of tell this avoids.
                        CallTimerDisplay(
                          seconds: _controller.elapsedSeconds,
                        ),
                        const Spacer(flex: 3),
                        CallControlGrid(
                          controller: _controller,
                          onKeypad: _openKeypad,
                        ),
                        const Spacer(flex: 2),
                        EndCallButton(onEnd: _hangUp),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
