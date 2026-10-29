package cn.edu.nuaa.nuaa_timetable.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * 精确刷新调度。
 *
 * `updatePeriodMillis` 最小 30 分钟且会被系统合并，无法保证"下课瞬间"
 * 与"零点换日"的准确性，因此额外用 AlarmManager 排两类闹钟。
 */
object WidgetAlarmScheduler {

    private const val REQ_MIDNIGHT = 200
    private const val REQ_SESSION_BASE = 300
    private const val MAX_SESSION_ALARMS = 12

    fun schedule(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        scheduleMidnight(context, manager)
        scheduleSessionEnds(context, manager)
    }

    private fun scheduleMidnight(context: Context, manager: AlarmManager) {
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 30)
            set(Calendar.MILLISECOND, 0)
        }
        setAlarm(context, manager, REQ_MIDNIGHT, next.timeInMillis)
    }

    private fun scheduleSessionEnds(context: Context, manager: AlarmManager) {
        val payload = WidgetStore.read(context) ?: return
        val days: JSONArray = payload.optJSONArray("days") ?: return
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.CHINA).format(Date())
        var day: JSONObject? = null
        for (i in 0 until days.length()) {
            val item = days.optJSONObject(i) ?: continue
            if (item.optString("date") == today) {
                day = item
                break
            }
        }
        val sessions = day?.optJSONArray("sessions") ?: return
        val now = System.currentTimeMillis()
        var slot = 0
        for (i in 0 until sessions.length()) {
            if (slot >= MAX_SESSION_ALARMS) break
            val item = sessions.optJSONObject(i) ?: continue
            val endMinutes = item.optInt("endMinutes", 0)
            if (endMinutes <= 0) continue // 午间加课无时刻
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, endMinutes / 60)
                set(Calendar.MINUTE, endMinutes % 60)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            if (target <= now) continue
            setAlarm(context, manager, REQ_SESSION_BASE + slot, target)
            slot++
        }
    }

    private fun setAlarm(
        context: Context,
        manager: AlarmManager,
        requestCode: Int,
        triggerAt: Long,
    ) {
        val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
            action = WidgetAlarmReceiver.ACTION_ALARM
        }
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            manager.canScheduleExactAlarms()
        try {
            if (exactAllowed) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            } else {
                manager.setWindow(AlarmManager.RTC_WAKEUP, triggerAt, 10 * 60 * 1000L, pending)
            }
        } catch (_: SecurityException) {
            manager.setWindow(AlarmManager.RTC_WAKEUP, triggerAt, 15 * 60 * 1000L, pending)
        }
    }
}
