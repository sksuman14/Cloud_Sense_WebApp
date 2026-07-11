package com.example.cloud_sense_webapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.cloud_sense_webapp.R

class CloudSenseWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("WidgetPrefs", Context.MODE_PRIVATE)
        val deviceId = prefs.getString("deviceId", "ANNAM001") ?: "ANNAM001"
        val temperature = prefs.getFloat("temperature", -999f)
        val isOnline = prefs.getBoolean("isOnline", true)
        val updatedTime = prefs.getString("updatedTime", "12:26 PM") ?: "12:26 PM"
        val windSpeed = prefs.getFloat("windSpeed", -999f)
        val rainfall = prefs.getFloat("rainfall", -999f)
        val location = prefs.getString("location", "") ?: ""

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Update text views
            views.setTextViewText(R.id.widget_title, "Cloud Sense")
            views.setTextViewText(R.id.widget_device, deviceId)
            views.setTextViewText(R.id.widget_temperature, if (temperature == -999f) "N/A" else String.format("%.2f\u00B0C", temperature))
            views.setTextViewText(R.id.widget_updated, "Updated: $updatedTime")
            // Show "N/A" when data is missing (sentinel value -999)
            views.setTextViewText(R.id.widget_wind_speed, if (windSpeed == -999f) "N/A" else String.format("%.1f m/s", windSpeed))
            views.setTextViewText(R.id.widget_rainfall, if (rainfall == -999f) "N/A" else String.format("%.1f mm", rainfall))
            views.setTextViewText(R.id.widget_location, location)

            // Status indicator
            if (isOnline) {
                views.setTextViewText(R.id.widget_status, "Online")
                views.setTextColor(R.id.widget_status, 0xFF4ADE80.toInt())
                views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_dot_online)
            } else {
                views.setTextViewText(R.id.widget_status, "Offline")
                views.setTextColor(R.id.widget_status, 0xFFEF4444.toInt())
                views.setImageViewResource(R.id.widget_status_dot, R.drawable.widget_dot_offline)
            }

            // Click-to-open: tapping anywhere on the widget opens the app
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
