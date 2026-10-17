# =========================================================================
# PROGUARD / R8 RULES FOR POLZET APP
# Target: Release Build, R8 Optimization & Google Play Store Stability
# =========================================================================

# -------------------------------------------------------------------------
# 1. FLUTTER CORE, ENGINE & EMBEDDING
# -------------------------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.**

# -------------------------------------------------------------------------
# 2. APPLICATION ENTRY & DYNAMIC CONVERSATION SHORTCUTS (MainActivity.kt)
# -------------------------------------------------------------------------
-keep class com.polzet_app.MainActivity { *; }
-keep class androidx.core.content.pm.ShortcutInfoCompat** { *; }
-keep class androidx.core.content.pm.ShortcutManagerCompat** { *; }
-keep class androidx.core.app.Person** { *; }
-keep class androidx.core.graphics.drawable.IconCompat** { *; }

# -------------------------------------------------------------------------
# 3. BIOMETRIC AUTHENTICATION & SECURITY (local_auth, local_auth_android)
# -------------------------------------------------------------------------
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**

# Cryptography & KeyStore (crypto, secure storage)
-keep class javax.crypto.** { *; }
-keep class android.security.keystore.** { *; }
-keep class java.security.KeyStore { *; }
-keep class androidx.security.crypto.** { *; }
-dontwarn javax.crypto.**

# -------------------------------------------------------------------------
# 4. FIREBASE SUITE & PLAY INTEGRITY (firebase_core, auth, messaging, app_check)
# -------------------------------------------------------------------------
# Firebase Core & Base Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Cloud Messaging (FCM)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Auth, App Check & Play Integrity (Phone OTP & App Attestation)
-keep class com.google.firebase.auth.** { *; }
-dontwarn com.google.firebase.auth.**
-keep class com.google.firebase.appcheck.** { *; }
-dontwarn com.google.firebase.appcheck.**
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.android.play.integrity.** { *; }
-dontwarn com.google.android.play.core.integrity.**
-dontwarn com.google.android.play.integrity.**

# -------------------------------------------------------------------------
# 5. GOOGLE SIGN-IN & CREDENTIAL MANAGER
# -------------------------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-keep class io.flutter.plugins.googlesignin.** { *; }
-dontwarn androidx.credentials.**
-dontwarn com.google.android.libraries.identity.googleid.**

# -------------------------------------------------------------------------
# 6. IN-APP UPDATE & PLAY CORE LIBS (in_app_update)
# -------------------------------------------------------------------------
-keep class com.google.android.play.core.appupdate.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.common.** { *; }
-keep class de.migus.in_app_update.** { *; }
-keep class eu.wewox.in_app_update.** { *; }
-dontwarn com.google.android.play.core.**

# -------------------------------------------------------------------------
# 7. MEDIA, CAMERA, IMAGE PICKING & CROPPING
# -------------------------------------------------------------------------
# Image Picker (Android System Photo Picker)
-keep class io.flutter.plugins.imagepicker.** { *; }

# Image Cropper (uCrop Activity & Native UI)
-keep class com.yalantis.ucrop** { *; }
-dontwarn com.yalantis.ucrop**
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }

# Media & Camera Plugin Registrations (photo_manager, camerax)
-keep class com.fluttercandies.photo_manager.** { *; }
-dontwarn com.fluttercandies.photo_manager.**
-keep class io.flutter.plugins.camerax.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# -------------------------------------------------------------------------
# 8. NOTIFICATIONS & TOASTS (flutter_local_notifications, fluttertoast)
# -------------------------------------------------------------------------
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class io.github.ponnamkarthik.toast.** { *; }

# -------------------------------------------------------------------------
# 9. APP LINKS, URL LAUNCHER, SHARE & FILE PROVIDER
# -------------------------------------------------------------------------
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class androidx.browser.customtabs.** { *; }
-dontwarn com.llfbandit.app_links.**

-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.share.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# -------------------------------------------------------------------------
# 10. DEVICE & STORAGE UTILITIES (package_info_plus, shared_preferences, sqflite)
# -------------------------------------------------------------------------
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# -------------------------------------------------------------------------
# 11. UI, LOTTIE ANIMATIONS & CACHING (lottie, cached_network_image)
# -------------------------------------------------------------------------
-keep class com.airbnb.lottie.** { *; }
-keep interface com.airbnb.lottie.** { *; }
-keep enum com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

-keep class com.baseflow.** { *; }
-dontwarn com.baseflow.**

# -------------------------------------------------------------------------
# 12. NETWORKING, HTTP, WEBSOCKETS & SERIALIZATION (dio, okhttp3, gson)
# -------------------------------------------------------------------------
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okhttp3.WebSocket { *; }
-keep class okhttp3.WebSocketListener { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Gson / JSON Serialization
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-dontwarn com.google.gson.**
-dontwarn sun.misc.**

# -------------------------------------------------------------------------
# 13. KOTLIN, COROUTINES, DESUGARING & RUNTIME
# -------------------------------------------------------------------------
-dontwarn kotlin.**
-dontwarn kotlin.Metadata
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Desugaring & Java 8+ APIs
-dontwarn java.lang.invoke.**
-dontwarn j$.**

# JNI
-keep class com.sun.jna.** { *; }

# -------------------------------------------------------------------------
# 14. PLAY CONSOLE STACK TRACE & CRASH DE-OBFUSCATION (Mapping Integrity)
# -------------------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions
-renamesourcefileattribute SourceFile

# Keep Native JNI Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable Implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable Implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}