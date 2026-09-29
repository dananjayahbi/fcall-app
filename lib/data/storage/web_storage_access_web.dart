/// Browser adapter exposing `window.localStorage` through [WebStorageApi].
library;

import 'package:web/web.dart' as web;

import 'key_value_store.dart';

class _JsWebStorageApi implements WebStorageApi {
  const _JsWebStorageApi();

  web.Storage get _s => web.window.localStorage;

  @override
  String? getItem(String key) => _s.getItem(key);

  @override
  void setItem(String key, String value) => _s.setItem(key, value);

  @override
  void removeItem(String key) => _s.removeItem(key);

  @override
  String? key(int index) => _s.key(index);

  @override
  int get length => _s.length;
}

WebStorageApi? get browserWebStorage => const _JsWebStorageApi();
