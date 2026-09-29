import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/models/contact.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/empty_state.dart';
import '../../contacts/widgets/contact_tile.dart';

/// Picks one contact to schedule a call for.
///
/// Returns the chosen [Contact], or `null` if the sheet was dismissed — the
/// caller must be able to tell "no choice" from "chose the empty contact", or a
/// dismissed sheet would silently clear the current profile.
class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key});

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact> _contacts = const <Contact>[];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Contact> all = await AppScope.read(context).contactRepository.load();
    if (!mounted) return;
    setState(() {
      _contacts = all;
      _loading = false;
    });
  }

  List<Contact> get _filtered {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _contacts;
    return _contacts
        .where(
          (Contact c) =>
              c.name.toLowerCase().contains(needle) ||
              c.number.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Contact> visible = _filtered;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                'Who is calling?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                autofocus: false,
                onChanged: (String value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search name or number',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No matches',
                      subtitle: 'Save a contact first, then pick them here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (BuildContext context, int index) {
                        final Contact contact = visible[index];
                        return ContactTile(
                          contact: contact,
                          onSelect: () => Navigator.of(context).pop(contact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
