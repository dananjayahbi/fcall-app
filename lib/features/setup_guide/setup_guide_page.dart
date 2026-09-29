import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/permission_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/call_orchestrator.dart';
import '../../services/platform/platform_bridge.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/section_header.dart';
import 'widgets/instruction_card.dart';
import 'widgets/permission_row.dart';

/// Spec §5: the Xiaomi HyperOS configuration matrix, plus the spec §7
/// verification checklist with honest per-item status.
class SetupGuidePage extends StatefulWidget {
  const SetupGuidePage({
    required this.orchestrator,
    required this.status,
    required this.onRefresh,
    super.key,
  });

  final CallOrchestrator orchestrator;
  final PermissionStatus status;
  final Future<void> Function() onRefresh;

  @override
  State<SetupGuidePage> createState() => _SetupGuidePageState();
}

class _SetupGuidePageState extends State<SetupGuidePage> {
  late PermissionStatus _status = widget.status;
  bool _busy = false;

  Future<void> _recheck() async {
    setState(() => _busy = true);
    await widget.onRefresh();
    if (!mounted) return;
    setState(() {
      _status = PermissionStatus(granted: _status.granted);
      _busy = false;
    });
  }

  PlatformBridge get _bridge => AppScope.read(context).bridge;

  /// Routes a matrix row to whichever deep link exists on this platform.
  void _openFor(String permissionId) {
    switch (permissionId) {
      case 'exactAlarm':
        _bridge.openExactAlarmSettings();
      case 'autostart':
        _bridge.openAutostartSettings();
      case 'notifications':
        _bridge.openNotificationSettings();
      default:
        _bridge.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text(
          'Device setup',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _busy ? null : _recheck,
            child: _busy
                ? const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Re-check'),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.huge),
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.lg),

          InstructionCard(
            title: 'One-time HyperOS setup',
            icon: Icons.checklist,
            children: const <Widget>[
              InstructionStep(
                'Open Settings, go to Apps, then Manage apps, then Incoming Call.',
                number: 1,
              ),
              InstructionStep(
                'Turn on Autostart so HyperOS stops killing the alarm worker.',
                number: 2,
              ),
              InstructionStep(
                'Set Battery saver to "No restrictions".',
                number: 3,
              ),
              InstructionStep(
                'Under Permissions, allow Display pop-up windows while running '
                'in the background.',
                number: 4,
              ),
              InstructionStep(
                'Under Other permissions, set Alarms & reminders to Allow.',
                number: 5,
              ),
            ],
          ),

          const SectionHeader('Permission matrix'),
          for (final PermissionRequirement requirement in PermissionMatrix.all)
            PermissionRow(
              requirement: requirement,
              granted: _status.isGranted(requirement.id),
              onOpen: () => _openFor(requirement.id),
            ),

          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Verification checklist'),
          const _ChecklistCard(),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Spec §7, transcribed with an honest split between what a web run can
/// demonstrate and what needs the handset.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

  static const List<(String, String, bool)> _items = <(String, String, bool)>[
    (
      'Screen-off takeover',
      'Lock the phone with a call armed. The screen must wake and show the '
          'call UI over the keyguard.',
      false,
    ),
    (
      'Proximity screen-off',
      'Answer, then cover the top bezel. The display must go dark and come '
          'back when uncovered, with the timer still running.',
      false,
    ),
    (
      'Total silence',
      'Answer and confirm no audio leaves either speaker.',
      false,
    ),
    (
      'Volume-key mute',
      'While ringing, press Volume Down. The ringer must stop and the call '
          'screen must stay up.',
      false,
    ),
    (
      'Native call log',
      'End the call and confirm the record appears in the Xiaomi Phone app.',
      false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool hardwareBacked = AppScope.of(context).bridge.isHardwareBacked;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                hardwareBacked ? Icons.phonelink_setup : Icons.schedule,
                size: 17,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hardwareBacked
                      ? 'Requires a physical Redmi 14C'
                      : 'Not verifiable on this platform',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Each item depends on Android hardware or a system provider, so a '
            'run of this build cannot clear them. They are listed un-ticked on '
            'purpose.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (String title, String detail, bool _) in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
