package cn.edu.nuaa.nuaa_timetable

import cn.edu.nuaa.nuaa_timetable.widget.WidgetStore
import cn.edu.nuaa.nuaa_timetable.widget.WidgetUpdater
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sync" -> {
                        val payload = call.arguments as? String
                        if (payload.isNullOrEmpty()) {
                            result.error("empty_payload", "payload 为空", null)
                        } else {
                            WidgetStore.write(this, payload)
                            WidgetUpdater.refreshAll(this)
                            result.success(null)
                        }
                    }

                    "clear" -> {
                        WidgetStore.clear(this)
                        WidgetUpdater.refreshAll(this)
                        result.success(null)
                    }

                    "refresh" -> {
                        WidgetUpdater.refreshAll(this)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        const val CHANNEL = "nuaa/timetable_widget"
    }
}
