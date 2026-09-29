# ProGuard / R8 rules for the release build.
#
# R8 runs over the whole APK in release mode, including the Kotlin sources and
# the Dart AOT snapshot's JNI entry points. Flutter and its plugins do a fair
# amount of reflection, so these rules are the difference between an APK that
# launches and one that dies on the first platform-channel call.

# --- Flutter embedding -------------------------------------------------------
# The engine looks these up by name over JNI; R8 cannot see the reference.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core (deferred components).
#
# io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
# hard-references the Play Core split-install API, but that path is only reached
# if the app calls installDeferredComponent() - which this app never does. The
# classes are not on the classpath, so R8 reports them as missing and (in
# minify mode) fails the build. They are genuinely unreachable, so silence them.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# GeneratedPluginRegistrant is constructed reflectively by the embedding.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# --- Entry points ------------------------------------------------------------
# MainActivity is named in AndroidManifest.xml only.
-keep class com.mobiletel.incomingcall.MainActivity { *; }
-keep class com.mobiletel.incomingcall.** { *; }

# --- Kotlin coroutines -------------------------------------------------------
# R8 cannot infer that continuation classes are used.
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# --- Diagnostics -------------------------------------------------------------
# Keep line numbers so a release crash report is actually readable, and hide the
# original source file name so the APK does not leak the build layout.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
