import 'package:flutter/material.dart';

import '../../../core/models/contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// One row in the contact book.
class ContactTile extends StatelessWidget {
  const ContactTile({
    required this.contact,
    super.key,
    this.onEdit,
    this.onDelete,
    this.onSelect,
  });

  final Contact contact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Present when the tile is being used as a picker rather than a list.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              ContactAvatar(contact: contact, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.number,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Edit',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Remove',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular initials badge.
///
/// The hue is derived from the contact's stable seed, so a given contact keeps
/// the same colour between sessions — a list where avatars reshuffle on every
/// launch reads as broken.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({required this.contact, super.key, this.size = 44});

  final Contact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final int hue = contact.colourSeed.abs() % 360;
    final Color background = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      0.32,
      0.34,
    ).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials(contact.displayName),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
