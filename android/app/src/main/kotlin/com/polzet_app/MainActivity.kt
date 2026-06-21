package com.polzet_app

import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.graphics.BitmapFactory
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.polzet_app/shortcuts"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // Android 15+ (API 35+)
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "createConversationShortcut") {
                val shortcutId = call.argument<String>("shortcutId")
                val displayName = call.argument<String>("displayName")
                val iconPath = call.argument<String>("iconPath")
                
                if (shortcutId != null && displayName != null) {
                    try {
                        createConversationShortcut(shortcutId, displayName, iconPath)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHORTCUT_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "shortcutId and displayName are required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
    
    private fun createConversationShortcut(shortcutId: String, displayName: String, iconPath: String?) {
        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("shortcut_chat_id", shortcutId)
        }
        
        val personBuilder = Person.Builder()
            .setName(displayName)
            .setKey(shortcutId)
            .setImportant(true)
            
        val shortcutBuilder = ShortcutInfoCompat.Builder(applicationContext, shortcutId)
            .setShortLabel(displayName)
            .setLongLived(true)
            .setIntent(intent)
            
        if (iconPath != null && File(iconPath).exists()) {
            val bitmap = BitmapFactory.decodeFile(iconPath)
            if (bitmap != null) {
                val icon = IconCompat.createWithBitmap(bitmap)
                personBuilder.setIcon(icon)
                shortcutBuilder.setIcon(icon)
            }
        }
        
        shortcutBuilder.setPerson(personBuilder.build())
        
        ShortcutManagerCompat.pushDynamicShortcut(applicationContext, shortcutBuilder.build())
    }
}
