import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/models/contact.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/contact_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import 'widgets/contact_tile.dart';

/// The saved contact book.
///
/// A plain list with add / edit / delete. Deliberately not backed by
/// `READ_CONTACTS`: importing the system address book would leak the user's
/// real contacts into an app whose entire premise is that it does not look
/// like the user's own phonebook, and it would require a permission that has
/// nothing to do with the feature.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  ContactRepository get _repo => AppScope.read(context).contactRepository;

  List<Contact> _contacts = const <Contact>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Contact> next = await _repo.load();
    if (!mounted) return;
    setState(() {
      _contacts = next;
      _loading = false;
    });
  }

  Future<void> _openEditor({Contact? existing}) async {
    final Contact? saved = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => ContactEditorSheet(
        contact: existing,
        suggestedId: _repo.newId(),
      ),
    );
    if (saved == null) return;
    await _repo.upsert(saved);
    await _load();
  }

  Future<void> _confirmDelete(Contact contact) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Remove ${contact.displayName}?'),
        content: const Text(
          'Calls already scheduled with this contact are kept — they carry '
          'their own copy of the details.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.remove(contact.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Add contact',
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? EmptyState(
              icon: Icons.contacts_outlined,
              title: 'No contacts yet',
              subtitle:
                  'Save a few numbers so you can pick who to call, or let the '
                  'app choose one at random.',
              action: TextButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Add a contact'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.huge),
              itemCount: _contacts.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                final Contact contact = _contacts[index];
                return ContactTile(
                  contact: contact,
                  onEdit: () => _openEditor(existing: contact),
                  onDelete: () => _confirmDelete(contact),
                );
              },
            ),
    );
  }
}

/// Add / edit form for one contact.
class ContactEditorSheet extends StatefulWidget {
  const ContactEditorSheet({required this.suggestedId, super.key, this.contact});

  final String suggestedId;
  final Contact? contact;

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.contact?.name ?? '',
  );
  late final TextEditingController _number = TextEditingController(
    text: widget.contact?.number ?? '',
  );
  String _simLabel = 'SIM 1';

  @override
  void initState() {
    super.initState();
    _simLabel = widget.contact?.simLabel ?? 'SIM 1';
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _save() {
    final String number = _number.text.trim();
    if (number.isEmpty) return;
    Navigator.of(context).pop(
      Contact(
        // Reuse the existing id so saving an edit updates rather than
        // duplicates — minting a new id here would fork the entry.
        id: widget.contact?.id ?? widget.suggestedId,
        name: _name.text.trim(),
        number: number,
        simLabel: _simLabel,
        avatarSeed: widget.contact?.avatarSeed ?? _name.text.hashCode,
      ),
    );
  }

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
              Text(
                widget.contact == null ? 'New contact' : 'Edit contact',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _number,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Number'),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'SIM 1', label: Text('SIM 1')),
                  ButtonSegment<String>(value: 'SIM 2', label: Text('SIM 2')),
                ],
                selected: <String>{_simLabel},
                onSelectionChanged: (Set<String> next) =>
                    setState(() => _simLabel = next.first),
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
                  TextButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
