package com.example.cloud_sense_webapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class CloudSenseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Read last stored data from SharedPreferences (pushed by Flutter app)
            val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)

            val deviceId = prefs.getString("deviceId", "N/A") ?: "N/A"
            val temperature = prefs.getFloat("temperature", -999f)
            val windSpeed = prefs.getFloat("windSpeed", -999f)
            val rainfall = prefs.getFloat("rainfall", -999f)
            val location = prefs.getString("location", "") ?: ""
            val isOnline = prefs.getBoolean("isOnline", false)
            val updatedTime = prefs.getString("updatedTime", "Unknown") ?: "Unknown"

            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            views.setTextViewText(R.id.widget_title, "Cloud Sense")
            views.setTextViewText(R.id.widget_device, deviceId)
            views.setTextViewText(R.id.widget_temperature,
                if (temperature != -999f) String.format("%.2f\u00B0C", temperature) else "N/A")
            views.setTextViewText(R.id.widget_wind_speed,
                if (windSpeed != -999f) String.format("%.1f m/s", windSpeed) else "N/A")
            views.setTextViewText(R.id.widget_rainfall,
                if (rainfall != -999f) String.format("%.1f mm", rainfall) else "N/A")
            views.setTextViewText(R.id.widget_location, location)
            views.setTextViewText(R.id.widget_updated, "Updated: $updatedTime")

            if (isOnline) {
                views.setTextViewText(R.id.widget_status, "Online")
                views.setTextColor(R.id.widget_status, 0xFF4ADE80.toInt())
                views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_dot_online)
            } else {
                views.setTextViewText(R.id.widget_status, "Offline")
                views.setTextColor(R.id.widget_status, 0xFFEF4444.toInt())
                views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_dot_offline)
            }

            // Click-to-open: tapping the widget opens the app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
