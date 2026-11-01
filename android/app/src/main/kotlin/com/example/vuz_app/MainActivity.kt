package com.example.vuz_app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    private val THEME_CHANNEL = "app.theme"
    private val ICON_CHANNEL = "app.icon"
    private val SECURITY_CHANNEL = "app.security"
    private val UPDATER_CHANNEL = "app.updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            THEME_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setThemeMode" -> {
                    val mode = call.argument<String>("mode")
                    applyThemeMode(mode)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    applySecureMode(enabled)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ICON_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getIcon" -> result.success(getAppIcon())
                "setIcon" -> {
                    val icon = call.argument<String>("icon") ?: "light"
                    val success = setAppIcon(icon)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPDATER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("filePath")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Path is empty", null)
                        return@setMethodCallHandler
                    }
                    val success = installApkFile(path)
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("INSTALL_FAILED", "Failed to start install intent", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApkFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.updateprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun applySecureMode(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
                )
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    private fun applyThemeMode(mode: String?) {
        when (mode) {
            "light" -> AppCompatDelegate.setDefaultNightMode(
                AppCompatDelegate.MODE_NIGHT_NO
            )
            "dark" -> AppCompatDelegate.setDefaultNightMode(
                AppCompatDelegate.MODE_NIGHT_YES
            )
            else -> AppCompatDelegate.setDefaultNightMode(
                AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
            )
        }
    }

    private fun getAppIcon(): String {
        return try {
            val pm = packageManager
            val pkg = packageName
            val darkComp = ComponentName(pkg, "$pkg.MainActivityDark")
            val state = pm.getComponentEnabledSetting(darkComp)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) "dark" else "light"
        } catch (e: Exception) {
            "light"
        }
    }

    private fun setAppIcon(variant: String): Boolean {
        return try {
            val pm = packageManager
            val pkg = packageName
            val mainComp = ComponentName(pkg, "$pkg.MainActivity")
            val darkComp = ComponentName(pkg, "$pkg.MainActivityDark")

            if (variant == "dark") {
                pm.setComponentEnabledSetting(
                    darkComp,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                pm.setComponentEnabledSetting(
                    mainComp,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            } else {
                pm.setComponentEnabledSetting(
                    mainComp,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                pm.setComponentEnabledSetting(
                    darkComp,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
