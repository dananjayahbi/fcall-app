import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/call_session.dart';
import '../../core/models/caller_profile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/logger.dart';
import '../../services/call_orchestrator.dart';
import '../../services/ringer/ringer_service.dart';
import 'widgets/answer_decline_bar.dart';
import 'widgets/caller_header.dart';
import 'widgets/ringer_indicator.dart';

/// Module 4: the HyperOS / Redmi 14C incoming-call takeover.
///
/// Three properties are load-bearing:
///
/// 1. **Nothing identifies the app.** A real dialer shows only the caller, the
///    ringer, and the two actions. There is no status chip, no badge, no hint
///    text and no branding — every extra widget is a giveaway to anyone who
///    sees the screen. Platform diagnostics live on a hidden page instead.
/// 2. **The actions never scroll away.** The identity block scrolls, the
///    answer/decline bar is pinned. A ringing call whose buttons need a swipe
///    to reach is a broken call screen.
/// 3. **System back cannot drop the call.** Back is routed to "decline" so the
///    user cannot leave without making a decision.
class IncomingCallPage extends StatefulWidget {
  const IncomingCallPage({
    required this.session,
    required this.orchestrator,
    super.key,
  });

  final CallSession session;
  final CallOrchestrator orchestrator;

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  StreamSubscription<RingerState>? _ringerSub;
  RingerState _ringerState = const RingerState();

  @override
  void initState() {
    super.initState();
    _ringerState = widget.orchestrator.ringer.state;
    _ringerSub = widget.orchestrator.ringer.stateStream.listen((RingerState s) {
      if (mounted) setState(() => _ringerState = s);
    });
    // Full immersion: this screen is a takeover, not a page inside the app.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _ringerSub?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _answer() async {
    AppLogger.instance.info('incoming', 'answer tapped');
    await widget.orchestrator.answer();
  }

  Future<void> _decline() async {
    AppLogger.instance.info('incoming', 'decline tapped');
    await widget.orchestrator.decline();
  }

  @override
  Widget build(BuildContext context) {
    final CallerProfile profile = CallerProfile(
      name: widget.session.profileName,
      number: widget.session.profileNumber,
      simLabel: widget.session.simLabel,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _decline();
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
              child: Column(
                children: <Widget>[
                  // The identity block scrolls on a short viewport; the
                  // actions below it are pinned and always reachable.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                                vertical: AppSpacing.lg,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  CallerHeader(
                                    profile: profile,
                                    animating: !_ringerState.silenced,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  RingerIndicator(state: _ringerState),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: AnswerDeclineBar(
                      onAnswer: _answer,
                      onDecline: _decline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
