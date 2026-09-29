import 'dart:async';

import 'package:flutter/material.dart';

import '../models/call_session.dart';
import '../../features/active_call/active_call_page.dart';
import '../../features/home/home_page.dart';
import '../../features/incoming_call/incoming_call_page.dart';
import '../../services/call_orchestrator.dart';

/// Declarative host for the call takeover.
///
/// The spec §4 lifecycle is a state machine, so the screen is derived from
/// [CallSession.phase] rather than pushed imperatively. That matters for a
/// subtle reason: on Android the call can be launched by a `BroadcastReceiver`
/// with no navigation history at all, so "push the incoming page" is not a
/// reliable primitive. Deriving the screen from the phase works identically
/// whether the app was already running or cold-started by the alarm.
class CallFlowHost extends StatefulWidget {
  const CallFlowHost({required this.orchestrator, super.key});

  final CallOrchestrator orchestrator;

  @override
  State<CallFlowHost> createState() => _CallFlowHostState();
}

class _CallFlowHostState extends State<CallFlowHost> {
  StreamSubscription<CallSession>? _sub;
  CallSession? _session;
  String? _pendingToast;

  @override
  void initState() {
    super.initState();
    _session = widget.orchestrator.session;
    _sub = widget.orchestrator.sessionStream.listen(_onSession);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onSession(CallSession next) {
    if (!mounted) return;
    final CallSession? previous = _session;
    setState(() {
      _session = next;
      if (next.phase == CallPhase.ended) {
        _pendingToast = _toastFor(next);
      } else if (next.phase == CallPhase.ringing &&
          previous?.phase == CallPhase.ended) {
        // A new call replaced a finished one — the old toast is stale.
        _pendingToast = null;
      }
    });
  }

  String _toastFor(CallSession session) {
    return switch (session.resolution) {
      CallResolution.answered => 'Call ended — ${session.displayName}',
      CallResolution.declined => 'Declined — logged as rejected',
      CallResolution.missed => 'Missed call — logged',
      null => 'Call ended',
    };
  }

  void _dismissToast() {
    if (mounted) setState(() => _pendingToast = null);
  }

  @override
  Widget build(BuildContext context) {
    final CallSession? session = _session;
    final CallPhase phase = session?.phase ?? CallPhase.idle;

    final Widget screen = switch (phase) {
      CallPhase.ringing => IncomingCallPage(
        session: session!,
        orchestrator: widget.orchestrator,
      ),
      CallPhase.active => ActiveCallPage(
        session: session!,
        orchestrator: widget.orchestrator,
      ),
      CallPhase.idle ||
      CallPhase.scheduled ||
      CallPhase.ended => HomePage(orchestrator: widget.orchestrator),
    };

    return Stack(
      children: <Widget>[
        Positioned.fill(child: screen),
        if (_pendingToast != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: _CallToast(message: _pendingToast!, onDismiss: _dismissToast),
          ),
      ],
    );
  }
}

class _CallToast extends StatelessWidget {
  const _CallToast({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1F2937),
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onDismiss,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF2F6FA),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.close, size: 16, color: Color(0xFF6C7C8C)),
            ],
          ),
        ),
      ),
    );
  }
}
