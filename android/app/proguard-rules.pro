# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Play Core task classes referenced by Flutter's deferred components
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

# Keep Flutter deferred component manager
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

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

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ✅ Share Plus Plugin
-keep class io.flutter.plugins.share.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# ✅ App Links / Deep Linking
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.llfbandit.app_links.** { *; }

# ✅ Custom MainActivity & Method Channels
-keep class com.polzet_app.MainActivity { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# ✅ Google Sign-In (google_sign_in)
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }

# ✅ Android Credential Manager (Required for google_sign_in 7+)
-keep class androidx.credentials.** { *; }
-dontwarn androidx.credentials.**

# ✅ WebSocket (if chat uses WebSocket connection)
-keep class okhttp3.WebSocket { *; }
-keep class okhttp3.WebSocketListener { *; }

# General Rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Gson (if using)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Retrofit (if using)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Exceptions

# OkHttp3
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**