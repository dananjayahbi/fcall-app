import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'key_value_store.dart';
import 'web_storage_access.dart';

/// Chooses the best available [KeyValueStore] for the current platform.
///
/// Order of preference:
///  1. Web -> `window.localStorage` (survives reload)
///  2. Android -> `SharedPreferences` via the method channel (survives reboot)
///  3. anything else -> in-memory (keeps the app usable in tests/desktop)
abstract final class StorageFactory {
  static const MethodChannel _channel = MethodChannel(
    'com.mobiletel.incomingcall/storage',
  );

  static KeyValueStore create() {
    if (kIsWeb) {
      final WebStorageApi? storage = browserWebStorage;
      if (storage != null) return LocalStorageStore(storage);
      return InMemoryKeyValueStore();
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return SharedPreferencesStore(_channel);
    }
    return InMemoryKeyValueStore();
  }
}

/// Android `SharedPreferences` store.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._channel);

  final MethodChannel _channel;

  Map<String, String> _cache = <String, String>{};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final Map<Object?, Object?>? all =
          await _channel.invokeMethod<Map<Object?, Object?>>('readAll');
      if (all != null) {
        _cache = <String, String>{
          for (final MapEntry<Object?, Object?> e in all.entries)
            '${e.key}': '${e.value}',
        };
      }
      _loaded = true;
    } on PlatformException catch (error) {
      debugPrint('SharedPreferencesStore load failed: ${error.message}');
    } on MissingPluginException {
      debugPrint('SharedPreferencesStore unavailable on this platform');
    }
  }

  @override
  Future<String?> read(String key) async {
    await _ensureLoaded();
    return _cache[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _cache[key] = value;
    try {
      await _channel.invokeMethod<void>('write', <String, dynamic>{
        'key': key,
        'value': value,
      });
    } on PlatformException catch (error) {
      debugPrint('SharedPreferencesStore.write failed: ${error.message}');
    } on MissingPluginException {
      // In-memory only.
    }
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
    try {
      await _channel.invokeMethod<void>('delete', <String, dynamic>{'key': key});
    } on PlatformException catch (error) {
      debugPrint('SharedPreferencesStore.delete failed: ${error.message}');
    } on MissingPluginException {
      // In-memory only.
    }
  }

  @override
  Future<Set<String>> keys() async {
    await _ensureLoaded();
    return _cache.keys.toSet();
  }
}
