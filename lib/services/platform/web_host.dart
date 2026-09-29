/// Conditional export so the web bridge can use browser JS interop without
/// dragging `dart:js_interop` into the Android build.
///
/// `web_host_offdevice.dart` is used on non-web targets; it compiles to a no-op.
library;

export 'web_host_offdevice.dart'
    if (dart.library.js_interop) 'web_host_web.dart';
