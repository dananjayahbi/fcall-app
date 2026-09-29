import 'package:flutter/material.dart';

import '../../core/models/call_outcome.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/time_formatter.dart';
import '../../core/app_scope.dart';
import '../../services/call_orchestrator.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'widgets/call_log_tile.dart';

/// Module 6: the in-app view of the calls that were recorded.
///
/// The banner is the important part. On Android the authoritative record is the
/// system `CallLog.Calls` row; this list is the app's own mirror of it. Saying
/// so plainly prevents a web run from being read as proof that the system
/// call log works.
class CallLogPage extends StatefulWidget {
  const CallLogPage({required this.orchestrator, super.key});

  final CallOrchestrator orchestrator;

  @override
  State<CallLogPage> createState() => _CallLogPageState();
}

class _CallLogPageState extends State<CallLogPage> {
  List<SimCallLogEntry> _entries = const <SimCallLogEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<SimCallLogEntry> entries =
        await widget.orchestrator.callLog.history();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Clear app call log?'),
        content: const Text(
          'This only clears the list inside this app. Records already written '
          'to the Android call history are unaffected.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.orchestrator.callLog.clear();
    await _load();
  }

  /// Grouped by calendar day, the way a dialer history is.
  Map<String, List<SimCallLogEntry>> get _grouped {
    final Map<String, List<SimCallLogEntry>> groups =
        <String, List<SimCallLogEntry>>{};
    for (final SimCallLogEntry entry in _entries) {
      final String day = TimeFormatter.relativeDay(entry.startedAt);
      groups.putIfAbsent(day, () => <SimCallLogEntry>[]).add(entry);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final bool hardwareBacked = AppScope.of(context).bridge.isHardwareBacked;

    return AppScaffold(
      appBar: AppBar(
        title: const Text(
          'Call log',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No calls recorded yet',
              subtitle:
                  'Schedule a call, let it ring, then answer or decline. '
                  'Every finished call is written here.',
            )
          : ListView(
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                const SizedBox(height: AppSpacing.lg),
                _StorageBanner(hardwareBacked: hardwareBacked),
                const SizedBox(height: AppSpacing.lg),
                for (final MapEntry<String, List<SimCallLogEntry>> group
                    in _grouped.entries) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      bottom: AppSpacing.md,
                    ),
                    child: Text(
                      group.key.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final SimCallLogEntry entry in group.value)
                    CallLogTile(
                      entry: entry,
                      highlight: entry == _entries.first,
                    ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

class _StorageBanner extends StatelessWidget {
  const _StorageBanner({required this.hardwareBacked});

  final bool hardwareBacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              hardwareBacked
                  ? 'These rows are the app\'s mirror of the records written to '
                        'the Android call history. Open the Xiaomi Phone app to '
                        'see the system copy.'
                  : 'Records are stored in this app. On an Android device they '
                        'are also written to the system call history.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
