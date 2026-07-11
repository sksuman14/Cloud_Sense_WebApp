package com.example.cloud_sense_webapp

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.cloud_sense_webapp/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgetData") {
                val deviceId = call.argument<String>("deviceId")
                val temperature = call.argument<Double>("temperature")
                val isOnline = call.argument<Boolean>("isOnline")
                val updatedTime = call.argument<String>("updatedTime")
                val windSpeed = call.argument<Double>("windSpeed")
                val rainfall = call.argument<Double>("rainfall")
                val location = call.argument<String>("location")

                val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("deviceId", deviceId)
                    // Use -999f as sentinel for "no data" (so widget shows N/A)
                    putFloat("temperature", temperature?.toFloat() ?: -999f)
                    putBoolean("isOnline", isOnline ?: false)
                    putString("updatedTime", updatedTime)
                    putFloat("windSpeed", windSpeed?.toFloat() ?: -999f)
                    putFloat("rainfall", rainfall?.toFloat() ?: -999f)
                    putString("location", location ?: "")
                    apply()
                }

                // Trigger update
                val intent = Intent(context, CloudSenseWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
                        ComponentName(context, CloudSenseWidgetProvider::class.java)
                    )
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
