import 'package:flutter/material.dart';

import '../../../core/models/contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/setting_switch_tile.dart';
import '../../contacts/widgets/contact_tile.dart';

/// Chooses where the caller for a scheduled call comes from.
///
/// Three mutually exclusive sources, shown as one card because they answer a
/// single question — "who will this call be from?" — and leaving them on
/// separate controls invites arming a call while not noticing which source is
/// active.
class CallerSourceCard extends StatelessWidget {
  const CallerSourceCard({
    required this.selectedContact,
    required this.randomMode,
    required this.hasSavedContact,
    required this.randomPreview,
    super.key,
    this.onPickContact,
    this.onToggleRandom,
    this.onClearContact,
  });

  /// Null means "use the numbers typed into the form below".
  final Contact? selectedContact;

  final bool randomMode;
  final bool hasSavedContact;

  /// The contact the randomiser would pick next, shown so the toggle is not a
  /// black box.
  final Contact? randomPreview;

  final VoidCallback? onPickContact;
  final ValueChanged<bool>? onToggleRandom;
  final VoidCallback? onClearContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: randomMode ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'CALLER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (randomMode)
            _RandomRow(preview: randomPreview)
          else if (selectedContact != null)
            Row(
              children: <Widget>[
                ContactAvatar(contact: selectedContact!, size: 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        selectedContact!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        selectedContact!.number,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClearContact,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Use the typed number instead',
                ),
              ],
            )
          else
            TextButton.icon(
              onPressed: onPickContact,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.contacts_outlined, size: 19),
              label: Text(
                hasSavedContact
                    ? 'Choose a contact'
                    : 'Save a contact to pick from the book',
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: AppSpacing.lg),
          SettingSwitchTile(
            title: 'Surprise me',
            subtitle: randomMode
                ? 'A different contact each time'
                : 'Always use the same caller',
            value: randomMode,
            // Disabled with an explanation rather than silently inert: without
            // this the switch looks broken when the book is empty.
            enabled: randomMode || hasSavedContact,
            onChanged: onToggleRandom,
            icon: Icons.casino_outlined,
          ),
        ],
      ),
    );
  }
}

class _RandomRow extends StatelessWidget {
  const _RandomRow({this.preview});

  final Contact? preview;

  @override
  Widget build(BuildContext context) {
    if (preview == null) {
      return const Row(
        children: <Widget>[
          Icon(Icons.casino_outlined, size: 19, color: AppColors.textSecondary),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'No contacts saved yet — add one to use this.',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        ContactAvatar(contact: preview!, size: 38),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                preview!.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'One of ${preview!.number}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
