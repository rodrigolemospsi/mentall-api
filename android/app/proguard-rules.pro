# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive CE
-keep class hive_ce.** { *; }
-keepattributes *Annotation*
-keep class com.mentall.app.models.** { *; }

# Riverpod
-keep class riverpod.** { *; }
-dontwarn riverpod.**

# Dart
-keep class dart.** { *; }

# Google Play Core (not used — deferred components)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
