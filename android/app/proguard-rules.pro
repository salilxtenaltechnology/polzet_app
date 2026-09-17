# =========================================================================
# PROGUARD / R8 RULES FOR POLZET APP
# Target: Release Build & Google Play Store Console Upload
# =========================================================================

# -------------------------------------------------------------------------
# 1. FLUTTER CORE & ENGINE
# -------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }

# -------------------------------------------------------------------------
# 2. APPLICATION ENTRY & CUSTOM NATIVE CODE (MainActivity)
# -------------------------------------------------------------------------
-keep class com.polzet_app.MainActivity { *; }
-keep class androidx.core.content.pm.ShortcutInfoCompat { *; }
-keep class androidx.core.content.pm.ShortcutManagerCompat { *; }
-keep class androidx.core.app.Person { *; }
-keep class androidx.core.graphics.drawable.IconCompat { *; }

# -------------------------------------------------------------------------
# 3. BIOMETRICS & SECURITY (local_auth, local_auth_android, crypto)
# -------------------------------------------------------------------------
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**

# Cryptography & KeyStore
-keep class javax.crypto.** { *; }
-keep class android.security.keystore.** { *; }
-keep class java.security.KeyStore { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn javax.crypto.**

# -------------------------------------------------------------------------
# 4. FIREBASE SUITE & GOOGLE PLAY SERVICES
# -------------------------------------------------------------------------
# Firebase Core & Base Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase Cloud Messaging (FCM)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Auth & App Check & Play Integrity (Phone OTP & Security)
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
-keep class eu.wewox.in_app_update.** { *; }
-keep class de.migus.in_app_update.** { *; }
-dontwarn com.google.android.play.core.appupdate.**
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

# -------------------------------------------------------------------------
# 7. MEDIA, CAMERA & IMAGE PICKER (photo_manager, wechat pickers, image_picker)
# -------------------------------------------------------------------------
# Fluttercandies (Photo Manager, WeChat Assets Picker, WeChat Camera Picker)
-keep class com.fluttercandies.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class com.luck.picture.lib.** { *; }
-dontwarn com.luck.picture.lib.**

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Image Cropper (uCrop)
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep class vn.hunghd.flutter.plugins.imagecropper.** { *; }

# Glide (Image engine for photo_manager / wechat_assets_picker)
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep class com.bumptech.glide.GeneratedAppGlideModuleImpl
-keep class * extends com.bumptech.glide.module.LibraryGlideModule
-keep class com.bumptech.glide.annotation.GlideModule
-keep public enum com.bumptech.glide.load.resource.bitmap.ImageHeaderParser$ImageType {
  public static **[] values();
  public static ** valueOf(java.lang.String);
}
-keep class com.bumptech.glide.load.data.ParcelFileDescriptorRewinder$InternalRewinder {
  *** rewind();
}
-dontwarn com.bumptech.glide.**

# -------------------------------------------------------------------------
# 8. VIDEO PLAYER & EXOPLAYER (video_player_android)
# -------------------------------------------------------------------------
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# -------------------------------------------------------------------------
# 9. NOTIFICATIONS & TOASTS (flutter_local_notifications, fluttertoast)
# -------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

-keep class io.github.ponnamkarthik.toast.** { *; }

# -------------------------------------------------------------------------
# 10. APP LINKS, URL LAUNCHER & SHARE (app_links, url_launcher, share_plus)
# -------------------------------------------------------------------------
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.llfbandit.app_links.** { *; }
-keep class androidx.browser.customtabs.** { *; }
-dontwarn com.llfbandit.app_links.**

-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.share.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# -------------------------------------------------------------------------
# 11. DEVICE & PACKAGE UTILITIES (package_info_plus, sensors_plus, shared_preferences, sqflite)
# -------------------------------------------------------------------------
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class dev.fluttercommunity.plus.sensors.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# -------------------------------------------------------------------------
# 12. UI, ANIMATIONS & CACHING (lottie, cached_network_image)
# -------------------------------------------------------------------------
-keep class com.airbnb.lottie.** { *; }
-keep interface com.airbnb.lottie.** { *; }
-keep enum com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**

-keep class com.baseflow.** { *; }

# -------------------------------------------------------------------------
# 13. NETWORKING, HTTP & WEBSOCKETS (dio, http, web_socket_channel, okhttp3)
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

# Retrofit & Gson (JSON Serialization)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Exceptions
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-dontwarn sun.misc.**

# -------------------------------------------------------------------------
# 14. KOTLIN, COROUTINES & DESUGARING
# -------------------------------------------------------------------------
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Desugaring & Java 8+ APIs
-dontwarn java.lang.invoke.**
-dontwarn j$.**

# JNI
-keep class com.sun.jna.** { *; }

# -------------------------------------------------------------------------
# 15. PLAY CONSOLE STACK TRACE & CRASH REPORT SYMBOLICATION
# -------------------------------------------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod
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