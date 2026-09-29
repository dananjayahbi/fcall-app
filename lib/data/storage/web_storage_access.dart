/// Conditional export so `dart:js_interop` never reaches the Android build.
library;

export 'web_storage_access_offdevice.dart'
    if (dart.library.js_interop) 'web_storage_access_web.dart';
