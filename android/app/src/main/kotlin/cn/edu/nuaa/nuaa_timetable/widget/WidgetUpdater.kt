package cn.edu.nuaa.nuaa_timetable.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.widget.RemoteViews
import cn.edu.nuaa.nuaa_timetable.R

/**
 * 统一刷新入口：重绘所有小组件实例并重排下一次精确刷新。
 */
object WidgetUpdater {

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, TimetableWidgetProvider::class.java),
        )
        if (ids.isEmpty()) return

        val views = RemoteViews(context.packageName, R.layout.widget_today)
        WidgetRenderer.render(context, views)
        for (id in ids) {
            manager.updateAppWidget(id, views)
        }
        WidgetAlarmScheduler.schedule(context)
    }
}
