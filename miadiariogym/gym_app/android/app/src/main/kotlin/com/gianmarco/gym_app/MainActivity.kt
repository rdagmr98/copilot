package com.gianmarco.gym_app

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gym_file_reader")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playBeep" -> {
                        try {
                            val durationMs = (call.arguments as? Int) ?: 400
                            val toneMusic = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            toneMusic.startTone(ToneGenerator.TONE_CDMA_SOFT_ERROR_LITE, durationMs)
                            Handler(Looper.getMainLooper()).postDelayed({
                                toneMusic.release()
                            }, (durationMs + 300).toLong())
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BEEP_ERROR", e.message, null)
                        }
                    }
                    "showTimerNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val timeStr = args["time"] as String
                            val subtitle = args["subtitle"] as String
                            val channelId = args["channel"] as String

                            val views = RemoteViews(packageName, R.layout.notification_timer)
                            views.setTextViewText(R.id.notif_time, timeStr)
                            views.setTextViewText(R.id.notif_label, subtitle)

                            val notification = NotificationCompat.Builder(this, channelId)
                                .setSmallIcon(R.drawable.ic_notification)
                                .setOngoing(true)
                                .setSilent(true)
                                .setAutoCancel(false)
                                .setCustomContentView(views)
                                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                                .build()

                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.notify(1, notification)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("TIMER_NOTIF_ERROR", e.message, null)
                        }
                    }
                    "cancelTimerNotification" -> {
                        try {
                            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            nm.cancel(1)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
