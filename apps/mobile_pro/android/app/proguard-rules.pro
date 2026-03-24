# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# WebRTC (Crucial for flutter_webrtc release builds)
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Prevent obfuscating native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Flutter embedding Play Store deferred components support
# We are not using these features, so we can ignore the missing warnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
