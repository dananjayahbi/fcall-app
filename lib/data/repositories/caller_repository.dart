import '../../core/models/caller_profile.dart';
import '../../core/utils/logger.dart';
import '../storage/key_value_store.dart';

/// Module 1 storage: persist the latest caller profile so the user can
/// re-trigger instantly without re-typing anything.
class CallerRepository {
  CallerRepository(this._store);

  static const String _key = 'caller_profile_v1';

  final KeyValueStore _store;

  Future<CallerProfile> load() async {
    final Map<String, dynamic>? json = await _store.readJson(_key);
    if (json == null) return const CallerProfile();
    return CallerProfile.fromJson(json);
  }

  Future<void> save(CallerProfile profile) async {
    await _store.writeJson(_key, profile.toJson());
    AppLogger.instance.info(
      'caller-repo',
      'saved "${profile.displayName}" <${profile.number}>',
    );
  }

  Future<void> clear() => _store.delete(_key);
}
