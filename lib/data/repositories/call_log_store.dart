import '../../core/models/call_outcome.dart';
import '../storage/key_value_store.dart';

/// Append-only store for the in-app call history.
///
/// On Android this DAO is **not** the record of truth — Module 6 writes to the
/// system `CallLog.Calls` provider. This DAO exists because:
///  * the web build has no call-log provider, and this is what makes the
///    behaviour observable there, and
///  * it lets the history screen show exactly what was written, immediately,
///    without needing the Contacts/Call Log runtime permission round-trip.
class CallLogStore {
  CallLogStore(this._store, {this.capacity = 50});

  static const String _key = 'sim_call_log_v1';

  final KeyValueStore _store;
  final int capacity;

  Future<List<SimCallLogEntry>> load() async {
    final List<Map<String, dynamic>> raw = await _store.readJsonList(_key);
    return raw
        .map(SimCallLogEntry.fromJson)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<void> append(SimCallLogEntry entry) async {
    final List<SimCallLogEntry> all = (await load()).toList();
    all.removeWhere((SimCallLogEntry e) => e.sessionId == entry.sessionId);
    all.insert(0, entry);
    final List<Map<String, dynamic>> trimmed = all
        .take(capacity)
        .map((SimCallLogEntry e) => e.toJson())
        .toList();
    await _store.writeJsonList(_key, trimmed);
  }

  Future<void> clear() => _store.delete(_key);
}
