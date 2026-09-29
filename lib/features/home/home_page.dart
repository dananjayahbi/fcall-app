import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/call_trigger.dart';
import '../../core/models/caller_profile.dart';
import '../../core/models/contact.dart';
import '../../core/models/permission_status.dart';
import '../../core/models/scheduled_call.dart';
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
import '../contacts/contacts_page.dart';
import '../schedule/schedule_page.dart';
import '../setup_guide/diagnostics_page.dart';
import '../setup_guide/setup_guide_page.dart';
import 'widgets/caller_form_card.dart';
import 'widgets/caller_source_card.dart';
import 'widgets/contact_picker_sheet.dart';
import 'widgets/delay_preset_row.dart';
import 'widgets/exact_time_picker_card.dart';
import 'widgets/permission_banner.dart';
import 'widgets/relative_delay_card.dart';
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

  /// `null` while a custom option is the active choice.
  Duration? _selectedPreset = const Duration(minutes: 5);
  DateTime _exactTime = DateTime.now().add(const Duration(minutes: 5));
  bool _useExactTime = false;

  /// The hand-entered "in N minutes/hours" mode.
  bool _useRelative = false;
  RelativeUnit _relativeUnit = RelativeUnit.minutes;
  int _relativeValue = CallTriggerPresets.defaultMinutes;

  /// Whichever way the caller for this schedule is chosen.
  Contact? _selectedContact;
  bool _randomMode = false;
  List<Contact> _contacts = const <Contact>[];

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
    final List<Contact> contacts = await scope.contactRepository.load();

    if (!mounted) return;
    setState(() {
      _profile = saved;
      _settings = widget.orchestrator.settings;
      _permissions = perms;
      _contacts = contacts;
      // The saved toggle is honoured on load so "surprise me" survives a
      // restart — the user asked for it to stay on.
      _randomMode = widget.orchestrator.settings.randomContact && contacts.isNotEmpty;
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
    if (_useRelative) {
      return CallTrigger.relative(value: _relativeValue, unit: _relativeUnit);
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

  /// Arms the call into the shared schedule book.
  ///
  /// Goes through [ScheduleBook] rather than `orchestrator.arm` so the call
  /// joins the multi-schedule timeline instead of occupying the old
  /// single-alarm slot. The single-slot path is still used by the quick-action
  /// trigger, which is inherently one-shot.
  Future<void> _arm() async {
    if (_busy) return;
    final AppScope scope = AppScope.read(context);

    final Contact? resolved = await _resolveCaller(scope);
    // `_resolveCaller` is async (it may hit the randomiser), so the widget can
    // be gone by the time it returns. Every path below touches context.
    if (!mounted) return;
    if (resolved == null) {
      // `_resolveCaller` already explained why it could not pick a caller.
      return;
    }
    final CallTrigger trigger = _effectiveTrigger;
    if (!trigger.isValid()) {
      _toast('That time has already passed — pick a later one.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final bool canExact = await _bridge.canScheduleExactAlarms();
    if (!mounted) return;
    if (!canExact) {
      setState(() => _busy = false);
      _toast(
        'Android needs the "Alarms & reminders" permission before an exact '
        'call can be scheduled.',
      );
      return;
    }

    final ScheduledCall? saved = await scope.scheduleBook.arm(
      contact: resolved,
      trigger: trigger,
      vibrate: _settings.vibrate,
      randomised: _randomMode,
    );

    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      saved == null
          ? 'Could not schedule the call.'
          : 'Call from ${saved.displayName} scheduled.',
    );
  }

  /// Works out who the scheduled call is from.
  ///
  /// Returns `null` and reports the reason when no caller can be determined, so
  /// a scheduled call never carries an empty number into the call log.
  Future<Contact?> _resolveCaller(AppScope scope) async {
    if (_randomMode) {
      final Contact? picked = await scope.contactRandomiser.pick();
      if (picked == null) {
        _toast('Add a contact to the book first — there is nobody to pick.');
        return null;
      }
      return picked;
    }
    if (_selectedContact != null) return _selectedContact;
    final CallerProfile profile = _currentProfile();
    if (!profile.hasNumber) {
      _toast('Pick a contact or enter a number first.');
      return null;
    }
    return Contact(
      id: '',
      name: profile.name,
      number: profile.number,
      simLabel: profile.simLabel,
    );
  }

  /// The contact the randomiser would pick next, for the card's preview.
  Contact? get _randomPreview {
    if (!_randomMode || _contacts.isEmpty) return null;
    // A preview, not a commitment: the actual pick happens at arm time so a
    // stale preview can never leak into a scheduled call.
    final int index = DateTime.now().millisecond % _contacts.length;
    return _contacts[index];
  }

  Future<void> _pickContact() async {
    final Contact? chosen = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const ContactPickerSheet(),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _selectedContact = chosen;
      // Picking a specific contact and leaving "surprise me" on at the same
      // time is ambiguous about which wins; the explicit choice wins.
      _randomMode = false;
      _updateSettings(_settings.copyWith(randomContact: false));
    });
  }

  void _updateSettings(AppSettings next) {
    setState(() => _settings = next);
    widget.orchestrator.persistSettings(next);
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
            tooltip: 'Contacts',
            icon: const Icon(Icons.contacts_outlined),
            onPressed: () => Navigator.of(context).push(
              fadeRoute<void>(const ContactsPage()),
            ),
          ),
          IconButton(
            tooltip: 'Scheduled calls',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => Navigator.of(context).push(
              fadeRoute<void>(const SchedulePage()),
            ),
          ),
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
                    // A call that has already been handled must not keep
                    // claiming it is ringing — see CountdownChip.
                    completed: widget.orchestrator.isInCall,
                    completedLabel: widget.orchestrator.isInCall
                        ? 'Call in progress'
                        : 'Call ended',
                    onCancel: _disarm,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                CallerSourceCard(
                  selectedContact: _selectedContact,
                  randomMode: _randomMode,
                  hasSavedContact: _contacts.isNotEmpty,
                  randomPreview: _randomPreview,
                  onPickContact: _pickContact,
                  onClearContact: () => setState(() => _selectedContact = null),
                  onToggleRandom: (bool value) {
                    setState(() => _randomMode = value);
                    // Persisted so leaving the toggle on keeps it on next
                    // launch, which is what "if I keep the toggle on" means.
                    _updateSettings(_settings.copyWith(randomContact: value));
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                CallerFormCard(
                  profile: _currentProfile(),
                  nameController: _nameController,
                  numberController: _numberController,
                  onChanged: () => setState(() {}),
                  onSimLabelChanged: _onSimLabelChanged,
                ),
                DelayPresetRow(
                  selected: (_useExactTime || _useRelative)
                      ? null
                      : _selectedPreset,
                  customActive: _useExactTime,
                  relativeActive: _useRelative,
                  onCustomRelative: () => setState(() {
                    _useRelative = true;
                    _useExactTime = false;
                  }),
                  onSelect: (Duration d) => setState(() {
                    _selectedPreset = d;
                    _useExactTime = false;
                    _useRelative = false;
                  }),
                  onCustom: () => setState(() {
                    _useExactTime = true;
                    _useRelative = false;
                  }),
                ),
                if (_useExactTime) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  ExactTimePickerCard(
                    value: _exactTime,
                    onChanged: (DateTime v) => setState(() => _exactTime = v),
                  ),
                ],
                if (_useRelative) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  RelativeDelayCard(
                    initialUnit: _relativeUnit,
                    initialValue: _relativeValue,
                    onChanged: (RelativeUnit unit, int value) => setState(() {
                      _relativeUnit = unit;
                      _relativeValue = value;
                    }),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                RingerSettingsCard(
                  settings: _settings,
                  onChanged: (AppSettings s) => _updateSettings(s),
                  onPreview: () => widget.orchestrator.ringer.preview(),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Schedule incoming call',
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
