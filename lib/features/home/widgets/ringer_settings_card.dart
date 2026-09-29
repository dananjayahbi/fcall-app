import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/setting_switch_tile.dart';

/// Module 1 audio & vibration toggles.
class RingerSettingsCard extends StatelessWidget {
  const RingerSettingsCard({
    required this.settings,
    required this.onChanged,
    required this.onPreview,
    super.key,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader('Ringer'),
        GlassCard(
          child: Column(
            children: <Widget>[
              SettingSwitchTile(
                title: 'Vibrate',
                subtitle: 'Loop the standard cellular vibration pattern',
                icon: Icons.vibration,
                value: settings.vibrate,
                onChanged: (bool v) => onChanged(settings.copyWith(vibrate: v)),
              ),
              const Divider(height: AppSpacing.xl),
              SettingSwitchTile(
                title: 'System ringtone',
                subtitle: 'Play the device default ringtone, not a bundled tone',
                icon: Icons.music_note_outlined,
                value: settings.useSystemRingtone,
                onChanged: (bool v) =>
                    onChanged(settings.copyWith(useSystemRingtone: v)),
              ),
              const Divider(height: AppSpacing.xl),
              SettingSwitchTile(
                title: 'Keep screen on while ringing',
                subtitle: 'Module 5 — hold the panel awake until answer or decline',
                icon: Icons.screen_lock_portrait_outlined,
                value: settings.screenOnWhileRinging,
                onChanged: (bool v) =>
                    onChanged(settings.copyWith(screenOnWhileRinging: v)),
              ),
              const Divider(height: AppSpacing.xl),
              SettingSwitchTile(
                title: 'Log completed calls',
                subtitle: 'Write the record into the Android call history',
                icon: Icons.history,
                value: settings.logCalls,
                onChanged: (bool v) => onChanged(settings.copyWith(logCalls: v)),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.play_arrow_rounded, size: 19),
                  label: const Text('Play ringtone'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
