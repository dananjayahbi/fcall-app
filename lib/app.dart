import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/routing/call_flow_host.dart';
import 'core/theme/app_theme.dart';

/// Application root.
///
/// The widget tree is intentionally shallow: [AppScope] provides the service
/// graph and [CallFlowHost] derives the visible screen from the call phase.
class IncomingCallApp extends StatefulWidget {
  const IncomingCallApp({required this.scope, super.key});

  final AppScope scope;

  @override
  State<IncomingCallApp> createState() => _IncomingCallAppState();
}

class _IncomingCallAppState extends State<IncomingCallApp> {
  @override
  void initState() {
    super.initState();
    // Started here rather than inside a page: the alarm can fire while no
    // page is mounted, and the ringing transition has to happen anyway.
    widget.scope.dispatcher.start();
  }

  @override
  void dispose() {
    widget.scope.dispatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      orchestrator: widget.scope.orchestrator,
      dispatcher: widget.scope.dispatcher,
      bridge: widget.scope.bridge,
      callerRepository: widget.scope.callerRepository,
      settingsRepository: widget.scope.settingsRepository,
      callLogService: widget.scope.callLogService,
      child: MaterialApp(
        title: 'Incoming Call',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: CallFlowHost(orchestrator: widget.scope.orchestrator),
      ),
    );
  }
}
