import 'dart:math';

import '../../core/models/contact.dart';
import '../../core/utils/logger.dart';
import '../storage/key_value_store.dart';

/// The saved contact book.
///
/// Storage shape is a single JSON list under one key rather than a key per
/// contact: the book is small, it is always read in full (the picker needs the
/// whole set to choose randomly), and a per-contact key scheme would need a
/// separate index that could drift from the records it indexes.
class ContactRepository {
  ContactRepository(this._store, {Random? random})
    : _random = random ?? Random();

  static const String _key = 'contact_book_v1';

  final KeyValueStore _store;
  final Random _random;

  /// Draws a uniform index in `[0, bound)`.
  ///
  /// Exposed on the repository (not the randomiser) so the whole picker is
  /// deterministic under test with a seeded [Random], and so "random" is one
  /// clearly-identified seam rather than a hidden [Random.nextInt] buried in
  /// selection logic.
  int nextRandomIndex(int bound) {
    if (bound <= 0) return 0;
    return _random.nextInt(bound);
  }

  Future<List<Contact>> load() async {
    final List<dynamic> raw = await _store.readJsonList(_key);
    if (raw.isEmpty) return const <Contact>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Contact.fromJson)
        .where((Contact c) => c.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> save(List<Contact> contacts) async {
    await _store.writeJsonList(
      _key,
      contacts.map((Contact c) => c.toJson()).toList(growable: false),
    );
    AppLogger.instance.info('contact-repo', 'saved ${contacts.length} contacts');
  }

  Future<List<Contact>> upsert(Contact contact) async {
    final List<Contact> current = List<Contact>.from(await load());
    final int index = current.indexWhere((Contact c) => c.id == contact.id);
    if (index >= 0) {
      current[index] = contact;
    } else {
      current.add(contact);
    }
    await save(current);
    return current;
  }

  Future<List<Contact>> remove(String id) async {
    final List<Contact> current = List<Contact>.from(await load());
    current.removeWhere((Contact c) => c.id == id);
    await save(current);
    return current;
  }

  Future<List<Contact>> clear() async {
    await _store.delete(_key);
    return const <Contact>[];
  }

  /// Mints an id that cannot collide with an existing one.
  ///
  /// Millisecond time plus a counter rather than a bare timestamp: two contacts
  /// saved inside the same millisecond (a fast double-tap on Save) would
  /// otherwise overwrite each other silently.
  String newId() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  int _counter = 0;
}

/// Picks a contact at random for the "surprise me" toggle.
///
/// Deliberately avoids picking the contact that was chosen last, so leaving the
/// toggle on produces a visibly *different* caller each time. A pure uniform
/// draw would repeat the previous pick roughly 1-in-N of the time, which reads
/// to the user as "the random toggle is broken" even though it is working.
class ContactRandomiser {
  ContactRandomiser(this._repository);

  final ContactRepository _repository;

  String? _lastPickId;

  /// Returns a random usable contact, or `null` when the book has none.
  ///
  /// Contacts without a number are excluded: they cannot be written to the
  /// call log, so selecting one would produce a call with no identity.
  Future<Contact?> pick() async {
    final List<Contact> all = await _repository.load();
    final List<Contact> usable =
        all.where((Contact c) => c.isUsable).toList(growable: false);
    if (usable.isEmpty) {
      _lastPickId = null;
      return null;
    }
    if (usable.length == 1) {
      _lastPickId = usable.first.id;
      return usable.first;
    }

    final List<Contact> candidates = usable
        .where((Contact c) => c.id != _lastPickId)
        .toList(growable: false);
    final List<Contact> pool = candidates.isEmpty ? usable : candidates;
    final Contact chosen = pool[_repository.nextRandomIndex(pool.length)];
    _lastPickId = chosen.id;
    AppLogger.instance.info('contact-random', 'picked ${chosen.displayName}');
    return chosen;
  }

  /// The most recent pick, so the UI can show who the next call will be for.
  Contact? get lastPick => _lastPick;

  Contact? _lastPick;

  void note(Contact contact) {
    _lastPick = contact;
    _lastPickId = contact.id;
  }
}
