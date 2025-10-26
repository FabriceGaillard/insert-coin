package com.example.insert_coin

import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "insert_coin/app"

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
						Log.d("MainActivity", "isAppInstalled: $packageName -> $installed")
						result.success(installed)
					} catch (e: Exception) {
						Log.e("MainActivity", "isAppInstalled error for $packageName", e)
						result.error("ERROR", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
