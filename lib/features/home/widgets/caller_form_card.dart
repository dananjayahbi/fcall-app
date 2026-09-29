import 'package:flutter/material.dart';

import '../../../core/models/caller_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/section_header.dart';

/// Module 1 contact identity: name, number and the SIM label shown on the
/// incoming-call screen.
class CallerFormCard extends StatelessWidget {
  const CallerFormCard({
    required this.profile,
    required this.nameController,
    required this.numberController,
    required this.onChanged,
    required this.onSimLabelChanged,
    super.key,
    this.showTitle = false,
  });

  final CallerProfile profile;
  final TextEditingController nameController;
  final TextEditingController numberController;

  /// Off by default because the caller-source card above already owns the
  /// "Caller" heading. Left on, the screen shows two identical headings.
  final bool showTitle;

  /// Fires on every keystroke so the avatar preview and derived profile stay
  /// in sync with the text fields rather than a stale cached copy.
  final VoidCallback onChanged;
  final ValueChanged<String> onSimLabelChanged;

  static const List<String> _simLabels = <String>['SIM 1', 'SIM 2', 'Dual SIM'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // No `SectionHeader` here: `CallerSourceCard` sits directly above and
        // already labels this group. Two stacked "Caller" headings read as a
        // rendering fault and give the screen no sense of which card is which.
        SectionHeader(
          showTitle ? 'Caller' : 'Or type a number',
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AvatarPreview(profile: profile),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: nameController,
                onChanged: (_) => onChanged(),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Caller name',
                  hintText: 'e.g. Dr. Silva',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: numberController,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+94 77 123 4567',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Caller ID label',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: _simLabels
                    .map(
                      (String label) => ChoiceChip(
                        label: Text(label),
                        selected: profile.simLabel == label,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryMuted,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: profile.simLabel == label
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                        onSelected: (_) => onSimLabelChanged(label),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.profile});

  final CallerProfile profile;

  @override
  Widget build(BuildContext context) {
    final Color hue = HSLColor.fromAHSL(
      1,
      profile.avatarHue,
      0.45,
      0.38,
    ).toColor();

    return Row(
      children: <Widget>[
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[hue, Color.lerp(hue, Colors.black, 0.28)!],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            profile.initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.hasName || profile.hasNumber
                    ? profile.displayName
                    : 'No caller set',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile.hasNumber ? profile.number : 'Enter a name and number',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
