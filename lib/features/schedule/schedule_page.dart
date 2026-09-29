import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/call_trigger.dart';
import '../../core/models/scheduled_call.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/timeline_gap_formatter.dart';
import '../../services/scheduling/schedule_book.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../home/widgets/exact_time_picker_card.dart';
import 'widgets/schedule_timeline_tile.dart';

/// Module 2/5 — every armed call, as a time line.
///
/// The scale for the gap column is chosen once for the whole list from the
/// *largest* gap, so every row's label is directly comparable. Computing it per
/// row is the specific mistake this avoids.
class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  ScheduleBook get _book => AppScope.read(context).scheduleBook;

  StreamSubscription<List<ScheduledCall>>? _sub;
  List<ScheduledCall> _calls = const <ScheduledCall>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _book.changes.listen((List<ScheduledCall> next) {
      if (mounted) setState(() => _calls = next);
    });
    _reload();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final List<ScheduledCall> next = await _book.load();
    if (!mounted) return;
    setState(() {
      _calls = next;
      _loading = false;
    });
  }

  TimelineGapScale get _scale {
    if (_calls.length < 2) return TimelineGapScale.minutes;
    Duration largest = Duration.zero;
    for (int i = 1; i < _calls.length; i++) {
      final Duration gap = _calls[i].fireAt.difference(_calls[i - 1].fireAt);
      if (gap > largest) largest = gap;
    }
    return TimelineGapFormatter.scaleFor(largest);
  }

  Future<void> _confirmDelete(ScheduledCall call) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this call?'),
        content: Text(
          'The scheduled call from ${call.displayName} will be cancelled.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _book.remove(call.id);
    await _reload();
  }

  Future<void> _edit(ScheduledCall call) async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _EditSheet(initial: call.fireAt),
    );
    if (picked == null) return;
    await _book.edit(existing: call, trigger: CallTrigger.exact(picked));
    await _reload();
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear all scheduled calls?'),
        content: const Text('Every armed call will be cancelled.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _book.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final TimelineGapScale scale = _scale;
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Scheduled calls'),
        actions: <Widget>[
          if (_calls.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
            ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No calls scheduled',
              subtitle:
                  'Arm a call from the home screen and it will appear here as '
                  'a point on the timeline.',
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                itemCount: _calls.length,
                itemBuilder: (BuildContext context, int index) {
                  final ScheduledCall call = _calls[index];
                  return ScheduleTimelineTile(
                    call: call,
                    scale: scale,
                    gapFromPrevious: index == 0
                        ? null
                        : call.fireAt.difference(_calls[index - 1].fireAt),
                    isFirst: true,
                    isLast: index == _calls.length - 1,
                    onEdit: () => _edit(call),
                    onDelete: () => _confirmDelete(call),
                  );
                },
              ),
            ),
    );
  }
}

/// Inline date + time editor used by the per-row edit action.
///
/// A bottom sheet rather than a separate route: editing is a small, reversible
/// adjustment, and pushing a full page for it would bury the timeline the user
/// was looking at.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.initial});

  final DateTime initial;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'New time',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ExactTimePickerCard(
                value: _value,
                onChanged: (DateTime next) => setState(() => _value = next),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_value),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
