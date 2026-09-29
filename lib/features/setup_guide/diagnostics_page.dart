import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/permission_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/call_orchestrator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/build_info_badge.dart';
import '../../widgets/section_header.dart';
import 'widgets/log_view.dart';
import 'widgets/proximity_state_chip.dart';

/// Hidden diagnostics.
///
/// Reachable only by long-pressing the app bar title. Nothing on any
/// user-facing screen links here, and no visible affordance hints that it
/// exists — a labelled "Diagnostics" entry would itself be a tell.
///
/// Its purpose is narrow and important: when a scheduled call does not arrive,
/// the question is always "what did the platform layer actually do?", and the
/// answer is only available if it was recorded somewhere.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({required this.orchestrator, super.key});

  final CallOrchestrator orchestrator;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  late List<String> _summary = const <String>[];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await AppScope.read(context).bridge.readPermissionStatus();
    if (!mounted) return;
    setState(() {
      _summary = status.missing
          .map((PermissionRequirement r) => '${r.hyperOsLabel} — ${r.title}')
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: <Widget>[
          TextButton(
            onPressed: _refresh,
            child: const Text('Re-check'),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          const Center(child: BuildInfoBadge()),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader('Permissions'),
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'All items granted',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            for (final String line in _summary)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  '• $line',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Sensor'),
          StreamBuilder<bool>(
            stream: widget.orchestrator.proximity.nearStream,
            initialData: widget.orchestrator.proximity.isNear,
            builder: (BuildContext context, AsyncSnapshot<bool> snap) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ProximityStateChip(isNear: snap.data ?? false),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Platform activity'),
          const LogView(),
        ],
      ),
    );
  }
}
