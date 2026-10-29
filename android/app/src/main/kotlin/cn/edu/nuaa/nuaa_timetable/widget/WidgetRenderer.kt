package cn.edu.nuaa.nuaa_timetable.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import cn.edu.nuaa.nuaa_timetable.MainActivity
import cn.edu.nuaa.nuaa_timetable.R
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 把 Dart 预计算好的 payload 映射到 RemoteViews。
 *
 * 布局约束：RemoteViews 不支持 ConstraintLayout / clipToOutline /
 * 自定义字体，因此全部使用 LinearLayout + shape drawable 的圆角实现。
 */
object WidgetRenderer {

    private const val STALE_DAYS = 7L

    fun render(context: Context, views: RemoteViews) {
        val payload = WidgetStore.read(context)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))

        if (payload == null) {
            showPlaceholder(
                context,
                views,
                dateText = todayLabel(),
                weekdayText = weekdayLabel(),
                message = context.getString(R.string.widget_no_data),
            )
            return
        }

        val day = pickDay(payload) ?: run {
            showPlaceholder(
                context,
                views,
                dateText = todayLabel(),
                weekdayText = weekdayLabel(),
                message = "数据可能过期，点按更新",
            )
            return
        }

        val dateText = day.optString("dateText", todayLabel())
        val weekdayText = day.optString("weekdayText", weekdayLabel())
        var remainingText = day.optString("remainingText", "")
        if (isStale(payload)) {
            remainingText = "数据可能过期，点按更新"
        }

        views.setTextViewText(R.id.tv_date, dateText)
        views.setTextViewText(R.id.tv_weekday, weekdayText)
        views.setTextViewText(R.id.tv_remaining, remainingText)

        // 强调色跟随 App 主题色；payload 未携带时沿用资源默认色。
        val accent = parseColor(payload.optString("accent"))
        if (accent != null) {
            views.setTextColor(R.id.tv_weekday, accent)
        }

        val focus = day.optJSONObject("focus")
        if (focus == null) {
            views.setTextViewText(R.id.tv_period, "—")
            views.setTextViewText(R.id.tv_course, day.optString("remainingText", "今天没有课程安排"))
            views.setTextViewText(R.id.tv_place, "")
            views.setTextViewText(R.id.tv_time, "")
            views.setViewVisibility(R.id.iv_place, View.GONE)
            views.setViewVisibility(R.id.iv_clock, View.GONE)
        } else {
            views.setTextViewText(R.id.tv_period, focus.optString("periodText", ""))
            views.setTextViewText(R.id.tv_course, focus.optString("name", ""))
            val place = focus.optString("place", "")
            views.setTextViewText(R.id.tv_place, place)
            views.setTextViewText(R.id.tv_time, focus.optString("timeText", ""))
            views.setViewVisibility(
                R.id.iv_place,
                if (place.isEmpty()) View.GONE else View.VISIBLE,
            )
            views.setViewVisibility(R.id.iv_clock, View.VISIBLE)
        }
    }

    /** 解析 `#RRGGBB` 形式的主题色。 */
    private fun parseColor(hex: String?): Int? {
        if (hex.isNullOrEmpty()) return null
        val cleaned = hex.removePrefix("#")
        if (cleaned.length != 6) return null
        return try {
            val value = cleaned.toLong(16)
            (0xFF000000L or value).toInt()
        } catch (_: NumberFormatException) {
            null
        }
    }

    private fun showPlaceholder(
        context: Context,
        views: RemoteViews,
        dateText: String,
        weekdayText: String,
        message: String,
    ) {
        views.setTextViewText(R.id.tv_date, dateText)
        views.setTextViewText(R.id.tv_weekday, weekdayText)
        views.setTextViewText(R.id.tv_remaining, context.getString(R.string.widget_description))
        views.setTextViewText(R.id.tv_period, "—")
        views.setTextViewText(R.id.tv_course, message)
        views.setTextViewText(R.id.tv_place, "")
        views.setTextViewText(R.id.tv_time, "")
        views.setViewVisibility(R.id.iv_place, View.GONE)
        views.setViewVisibility(R.id.iv_clock, View.GONE)
    }

    /** 按 payload 内的日期字段匹配今天；找不到则回退到第一条。 */
    private fun pickDay(payload: JSONObject): JSONObject? {
        val days: JSONArray = payload.optJSONArray("days") ?: return null
        if (days.length() == 0) return null
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.CHINA).format(Date())
        for (i in 0 until days.length()) {
            val day = days.optJSONObject(i) ?: continue
            if (day.optString("date") == today) return day
        }
        return days.optJSONObject(0)
    }

    private fun isStale(payload: JSONObject): Boolean {
        val raw = payload.optString("generatedAt")
        if (raw.length < 19) return false
        return try {
            // payload 使用 ISO8601 带时区偏移，这里只取到秒并忽略偏移
            // （同一时区内足够用于"是否过期"判断）。
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.CHINA)
            val generated = sdf.parse(raw.substring(0, 19))?.time ?: return false
            val diffDays = (System.currentTimeMillis() - generated) / (24 * 3600 * 1000L)
            diffDays > STALE_DAYS
        } catch (_: Exception) {
            false
        }
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            1001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun todayLabel(): String {
        val c = Calendar.getInstance()
        return "${c.get(Calendar.MONTH) + 1}月${c.get(Calendar.DAY_OF_MONTH)}日"
    }

    private fun weekdayLabel(): String {
        val names = arrayOf("星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六")
        return names[Calendar.getInstance().get(Calendar.DAY_OF_WEEK) - 1]
    }
}
