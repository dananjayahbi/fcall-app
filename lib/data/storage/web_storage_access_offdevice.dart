/// Non-web accessor — there is no `localStorage` outside a browser.
library;

import 'key_value_store.dart';

WebStorageApi? get browserWebStorage => null;
