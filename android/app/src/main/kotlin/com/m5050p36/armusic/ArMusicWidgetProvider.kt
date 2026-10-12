package com.m5050p36.armusic

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class ArMusicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        mgr: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.ar_music_widget)

        // اقرأ العنوان من SharedPreferences التي يكتبها التطبيق
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE
        )
        val title = prefs.getString("current_title", "AR Music & Video")
        val subtitle = prefs.getString("current_subtitle", "مشغل الوسائط")

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_subtitle, subtitle)

        // فتح التطبيق عند الضغط
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (android.os.Build.VERSION.SDK_INT >= 23)
                    PendingIntent.FLAG_IMMUTABLE else 0)
        )
        views.setOnClickPendingIntent(R.id.widget_action, pi)
        views.setOnClickPendingIntent(R.id.widget_title, pi)

        mgr.updateAppWidget(widgetId, views)
    }
}
