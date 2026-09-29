import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Minimal persistence contract used by the repositories.
///
/// Deliberately tiny: the app stores a handful of JSON documents, and adding a
/// full database would pull in a dependency that cannot be used from the web
/// build without extra work. [InMemoryKeyValueStore] is the default so the app
/// still runs if a platform store is unavailable.
abstract class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<Set<String>> keys();
}

/// In-memory implementation — also the fallback whenever a persistent store
/// cannot be opened.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? seed])
    : _map = <String, String>{...?seed};

  final Map<String, String> _map;

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  Future<Set<String>> keys() async => _map.keys.toSet();
}

/// A `Web Storage`-shaped API, so the browser store can be unit tested without
/// a browser and without `dart:js_interop` appearing in the signature.
abstract class WebStorageApi {
  String? getItem(String key);

  void setItem(String key, String value);

  void removeItem(String key);

  String? key(int index);

  int get length;
}

/// [KeyValueStore] over a [WebStorageApi] (`window.localStorage` on the web).
class LocalStorageStore implements KeyValueStore {
  LocalStorageStore(this._storage);

  final WebStorageApi _storage;

  @override
  Future<String?> read(String key) async => _storage.getItem(key);

  @override
  Future<void> write(String key, String value) async =>
      _storage.setItem(key, value);

  @override
  Future<void> delete(String key) async => _storage.removeItem(key);

  @override
  Future<Set<String>> keys() async {
    final Set<String> result = <String>{};
    final int count = _storage.length;
    for (int i = 0; i < count; i++) {
      final String? k = _storage.key(i);
      if (k != null) result.add(k);
    }
    return result;
  }
}

/// JSON helpers layered on top of a [KeyValueStore].
extension JsonStore on KeyValueStore {
  Future<Map<String, dynamic>?> readJson(String key) async {
    final String? raw = await read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      debugPrint('readJson("$key") malformed: $error');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final String? raw = await read(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map<Map<String, dynamic>>(Map<String, dynamic>.from)
            .toList();
      }
    } on FormatException catch (error) {
      debugPrint('readJsonList("$key") malformed: $error');
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      write(key, jsonEncode(value));

  Future<void> writeJsonList(String key, List<Map<String, dynamic>> value) =>
      write(key, jsonEncode(value));
}
