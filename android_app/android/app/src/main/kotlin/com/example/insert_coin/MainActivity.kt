package com.example.back_to_childhood

import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "back_to_childhood/app"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    try {
                        val pm = applicationContext.packageManager
                        val installed = try {
                            pm.getApplicationInfo(packageName, 0)
                            true
                        } catch (e: PackageManager.NameNotFoundException) {
                            false
                        }
                        result.success(installed)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error checking package: $packageName", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    try {
                        val pm = applicationContext.packageManager
                        val intent = pm.getLaunchIntentForPackage(packageName)
                        if (intent != null) {
                            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            applicationContext.startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NOT_FOUND", "No launch intent found for $packageName", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error opening app: $packageName", e)
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
