package cn.edu.nuaa.nuaa_timetable.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 刷新触发入口：跨日闹钟、下课闹钟，以及开机/换时区/安装更新等系统事件。
 */
class WidgetAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_ALARM,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED -> WidgetUpdater.refreshAll(context)
        }
    }

    companion object {
        const val ACTION_ALARM = "cn.edu.nuaa.nuaa_timetable.widget.ACTION_ALARM"
    }
}
