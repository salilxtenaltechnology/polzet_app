# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Biometric Authentication (local_auth)
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }

# Android KeyStore & Crypto
-keep class javax.crypto.** { *; }
-keep class android.security.keystore.** { *; }
-keep class java.security.KeyStore { *; }
-dontwarn javax.crypto.**

# SecureStorage (if using flutter_secure_storage)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }

# SharedPreferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Image Cropper & OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }

# Firebase (minimal - only if you add Firebase features later)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# General Rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}