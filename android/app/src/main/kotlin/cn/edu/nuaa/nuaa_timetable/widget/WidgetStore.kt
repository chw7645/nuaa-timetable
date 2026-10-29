package cn.edu.nuaa.nuaa_timetable.widget

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * 小组件数据的原生存储。
 *
 * 刻意不使用 SharedPreferences：Flutter 侧的 shared_preferences 在新版本
 * 走 DataStore（protobuf），原生无法直接读取。这里由 Dart 通过
 * MethodChannel 下发 JSON，原生以文件方式原子写入。
 */
object WidgetStore {

    private const val DIR = "nuaa_widget"
    private const val FILE = "payload.json"

    fun file(context: Context): File = File(File(context.filesDir, DIR), FILE)

    fun read(context: Context): JSONObject? {
        val f = file(context)
        if (!f.exists()) return null
        return try {
            JSONObject(f.readText(Charsets.UTF_8))
        } catch (_: Exception) {
            null
        }
    }

    /** tmp + rename 保证读到的永远是完整 JSON。 */
    fun write(context: Context, payload: String) {
        val target = file(context)
        target.parentFile?.mkdirs()
        val tmp = File(target.parentFile, "$FILE.tmp")
        tmp.writeText(payload, Charsets.UTF_8)
        if (!tmp.renameTo(target)) {
            target.writeText(payload, Charsets.UTF_8)
            tmp.delete()
        }
    }

    fun clear(context: Context) {
        file(context).delete()
    }
}
