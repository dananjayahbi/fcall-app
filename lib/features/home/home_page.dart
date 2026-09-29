import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/call_trigger.dart';
import '../../core/models/caller_profile.dart';
import '../../core/models/permission_status.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/call_orchestrator.dart';
import '../../services/platform/platform_bridge.dart';
import '../../services/scheduling/schedule_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/countdown_chip.dart';
import '../../widgets/primary_button.dart';
import '../call_log/call_log_page.dart';
import '../setup_guide/diagnostics_page.dart';
import '../setup_guide/setup_guide_page.dart';
import 'widgets/caller_form_card.dart';
import 'widgets/delay_preset_row.dart';
import 'widgets/exact_time_picker_card.dart';
import 'widgets/permission_banner.dart';
import 'widgets/ringer_settings_card.dart';

/// Module 1: the configuration + scheduling screen.
class HomePage extends StatefulWidget {
  const HomePage({required this.orchestrator, super.key});

  final CallOrchestrator orchestrator;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;

  CallerProfile _profile = const CallerProfile();
  AppSettings _settings = const AppSettings();
  PermissionStatus _permissions = const PermissionStatus();

  /// `null` while the exact-time picker is the active choice.
  Duration? _selectedPreset = const Duration(minutes: 5);
  DateTime _exactTime = DateTime.now().add(const Duration(minutes: 5));
  bool _useExactTime = false;

  bool _busy = false;
  bool _loading = true;

  PlatformBridge get _bridge => AppScope.read(context).bridge;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _numberController = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final AppScope scope = AppScope.read(context);
    final CallerProfile saved = await scope.callerRepository.load();
    await widget.orchestrator.loadPersisted();
    final PermissionStatus perms = await scope.bridge.readPermissionStatus();
    final Map<String, dynamic>? launch = await scope.bridge.consumeLaunchIntent();

    if (!mounted) return;
    setState(() {
      _profile = saved;
      _settings = widget.orchestrator.settings;
      _permissions = perms;
      _nameController.text = saved.name;
      _numberController.text = saved.number;
      _loading = false;
    });

    // Module 2 fallback: the app was cold-started by the quick-action tile.
    // The dispatcher handles the running-app case; this covers the cold start
    // where the launch intent is only readable once, here.
    if (launch != null && launch['event'] == 'quickRing') {
      AppLogger.instance.info('home', 'quick-action launch $launch');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _armQuickAction();
      });
    }
  }

  void _onSimLabelChanged(String label) {
    setState(() => _profile = _profile.copyWith(simLabel: label));
  }

  CallTrigger get _effectiveTrigger {
    if (_useExactTime) {
      return CallTrigger.exact(_exactTime);
    }
    return CallTrigger.countdown(
      delay: _selectedPreset ?? const Duration(minutes: 1),
      presetLabel: _presetLabelFor(_selectedPreset),
    );
  }

  String? _presetLabelFor(Duration? duration) {
    if (duration == null) return null;
    for (final option in CallTriggerPresets.all) {
      if (option.duration == duration) return option.label;
    }
    return null;
  }

  Future<void> _arm() async {
    if (_busy) return;
    final CallerProfile profile = _currentProfile();
    if (!profile.hasNumber) {
      _toast('Enter a phone number first — it goes into the call log.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final ScheduleResult result = await widget.orchestrator.arm(
      profile: profile,
      trigger: _effectiveTrigger,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      result.ok
          ? 'Incoming call armed. Lock the screen to test the takeover.'
          : result.message ?? 'Could not schedule the call.',
    );
  }

  /// Reads the live text fields so the controller values, not a stale cached
  /// profile, are what gets scheduled.
  CallerProfile _currentProfile() {
    return _profile.copyWith(
      name: _nameController.text,
      number: _numberController.text,
      avatarSeed: _nameController.text.hashCode & 0x7fffffff,
    );
  }

  Future<void> _armQuickAction() async {
    final CallerProfile profile = _currentProfile();
    final ScheduleResult result = await widget.orchestrator.armQuickAction(
      profile: profile.hasNumber ? profile : null,
    );
    if (!mounted || result.ok) return;
    _toast(result.message ?? 'Quick trigger failed.');
  }

  Future<void> _disarm() async {
    await widget.orchestrator.disarm();
    if (!mounted) return;
    setState(() {});
    _toast('Scheduled call cancelled.');
  }

  Future<void> _refreshPermissions() async {
    final PermissionStatus perms = await _bridge.readPermissionStatus();
    if (!mounted) return;
    setState(() => _permissions = perms);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  void _openDiagnostics() {
    Navigator.of(context).push(
      fadeRoute<void>(
        DiagnosticsPage(orchestrator: widget.orchestrator),
      ),
    );
  }

  void _openSetupGuide() {
    Navigator.of(context).push(
      fadeRoute<void>(
        SetupGuidePage(
          orchestrator: widget.orchestrator,
          status: _permissions,
          onRefresh: _refreshPermissions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        // Long-press is the only route to diagnostics. It is undiscoverable on
        // purpose: a visible "Diagnostics" entry would advertise that this app
        // does something unusual.
        title: GestureDetector(
          onLongPress: _openDiagnostics,
          behavior: HitTestBehavior.opaque,
          child: const Text(
            'Incoming Call',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Call log',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              fadeRoute<void>(CallLogPage(orchestrator: widget.orchestrator)),
            ),
          ),
          IconButton(
            tooltip: 'Device setup',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSetupGuide,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.huge),
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                const SizedBox(height: AppSpacing.lg),
                PermissionBanner(
                  status: _permissions,
                  onOpen: _openSetupGuide,
                  hardwareBacked: _bridge.isHardwareBacked,
                ),
                if (widget.orchestrator.isArmed) ...<Widget>[
                  CountdownChip(
                    fireAt: widget.orchestrator.armedTrigger!.fireAt,
                    onCancel: _disarm,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                CallerFormCard(
                  profile: _currentProfile(),
                  nameController: _nameController,
                  numberController: _numberController,
                  onChanged: () => setState(() {}),
                  onSimLabelChanged: _onSimLabelChanged,
                ),
                DelayPresetRow(
                  selected: _useExactTime ? null : _selectedPreset,
                  customActive: _useExactTime,
                  onSelect: (Duration d) => setState(() {
                    _selectedPreset = d;
                    _useExactTime = false;
                  }),
                  onCustom: () => setState(() => _useExactTime = true),
                ),
                if (_useExactTime) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  ExactTimePickerCard(
                    value: _exactTime,
                    onChanged: (DateTime v) => setState(() => _exactTime = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                RingerSettingsCard(
                  settings: _settings,
                  onChanged: (AppSettings s) {
                    setState(() => _settings = s);
                    widget.orchestrator.persistSettings(s);
                  },
                  onPreview: () => widget.orchestrator.ringer.preview(),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: widget.orchestrator.isArmed
                      ? 'Re-arm with current settings'
                      : 'Schedule incoming call',
                  icon: Icons.notifications_active_outlined,
                  busy: _busy,
                  onPressed: _arm,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _armQuickAction,
                    icon: const Icon(Icons.bolt, size: 19),
                    label: const Text('Quick trigger — rings in 10s'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _Note(
                  icon: Icons.info_outline,
                  text: 'The profile is saved locally, so the quick trigger '
                      'works without re-typing anything.',
                ),
              ],
            ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
