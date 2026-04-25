package com.gianmarco.gym_app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    private var workoutNativeAdFactory: WorkoutNativeAdFactory? = null
    private var timerNotificationToken: Long = 0

    private fun timerFinishedPendingIntent(title: String = "", body: String = ""): PendingIntent {
        val intent = Intent(this, TimerFinishedReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            this,
            1002,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleTimerFinishedNotification(delayMs: Long, title: String, body: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = timerFinishedPendingIntent(title, body)
        alarmManager.cancel(pendingIntent)
        val triggerAt = System.currentTimeMillis() + delayMs.coerceAtLeast(0L)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun cancelScheduledTimerFinishedNotification() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = timerFinishedPendingIntent()
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun streakReminderPendingIntent(title: String = "", body: String = ""): PendingIntent {
        val intent = Intent(this, StreakReminderReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        return PendingIntent.getBroadcast(
            this,
            1991,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun scheduleStreakReminderNotification(delayMs: Long, title: String, body: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = streakReminderPendingIntent(title, body)
        alarmManager.cancel(pendingIntent)
        val triggerAt = System.currentTimeMillis() + delayMs.coerceAtLeast(0L)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun cancelScheduledStreakReminderNotification() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = streakReminderPendingIntent()
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun cancelCountdownNotification() {
        timerNotificationToken += 1
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun clearNow() {
            nm.cancel(1)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                nm.activeNotifications
                    .filter {
                        it.id == 1 || it.notification.channelId == "timer_gym_cd"
                    }
                    .forEach { active -> nm.cancel(active.id) }
            }
        }
        clearNow()
        Handler(Looper.getMainLooper()).postDelayed({ clearNow() }, 180)
    }

    private fun cancelTimerNotifications() {
        timerNotificationToken += 1
        cancelScheduledTimerFinishedNotification()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun clearNow() {
            nm.cancel(0)
            nm.cancel(1)
            nm.cancel(2)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                nm.activeNotifications
                    .filter {
                        it.id == 0 ||
                            it.id == 1 ||
                            it.id == 2 ||
                            it.notification.channelId == "timer_gym" ||
                            it.notification.channelId == "timer_gym_alert" ||
                            it.notification.channelId == "timer_gym_cd"
                    }
                    .forEach { active -> nm.cancel(active.id) }
            }
        }
        clearNow()
        Handler(Looper.getMainLooper()).postDelayed({ clearNow() }, 180)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        workoutNativeAdFactory = WorkoutNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "workout_native",
            workoutNativeAdFactory!!
        )
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
                            val remainingSeconds = (args["remainingSeconds"] as? Number)?.toLong() ?: 0L
                            val token = (args["token"] as? Number)?.toLong() ?: 0L
                            if (token < timerNotificationToken) {
                                result.success(null)
                                return@setMethodCallHandler
                            }
                            timerNotificationToken = token

                            val views = RemoteViews(packageName, R.layout.notification_timer)
                            views.setTextViewText(R.id.notif_label, subtitle)
                            // Force visible colors for dark notification panels (Xiaomi MIUI, etc.)
                            views.setInt(R.id.notif_time, "setTextColor", 0xFFFFFFFF.toInt())
                            views.setInt(R.id.notif_label, "setTextColor", 0xFFFFFFFF.toInt())
                            val durationMs = remainingSeconds.coerceAtLeast(0L) * 1000L
                            val chronometerBase = SystemClock.elapsedRealtime() + durationMs
                            views.setChronometer(R.id.notif_time, chronometerBase, null, true)
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                                views.setChronometerCountDown(R.id.notif_time, true)
                            } else {
                                views.setTextViewText(R.id.notif_time, timeStr)
                            }

                            val notification = NotificationCompat.Builder(this, channelId)
                                .setSmallIcon(R.drawable.ic_notification)
                                .setColor(0xFFFF6B00.toInt())
                                .setOngoing(true)
                                .setSilent(true)
                                .setAutoCancel(false)
                                .setOnlyAlertOnce(true)
                                .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
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
                            cancelTimerNotifications()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_ERROR", e.message, null)
                        }
                    }
                    "cancelCountdownNotification" -> {
                        try {
                            cancelCountdownNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_COUNTDOWN_ERROR", e.message, null)
                        }
                    }
                    "scheduleTimerFinishedNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val delayMs = (args["delayMs"] as? Number)?.toLong() ?: 0L
                            val title = args["title"] as? String ?: ""
                            val body = args["body"] as? String ?: ""
                            scheduleTimerFinishedNotification(delayMs, title, body)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_TIMER_FINISHED_ERROR", e.message, null)
                        }
                    }
                    "cancelTimerFinishedNotification" -> {
                        try {
                            cancelScheduledTimerFinishedNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_TIMER_FINISHED_ERROR", e.message, null)
                        }
                    }
                    "scheduleStreakReminderNotification" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val delayMs = (args["delayMs"] as? Number)?.toLong() ?: 0L
                            val title = args["title"] as? String ?: ""
                            val body = args["body"] as? String ?: ""
                            scheduleStreakReminderNotification(delayMs, title, body)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SCHEDULE_STREAK_REMINDER_ERROR", e.message, null)
                        }
                    }
                    "cancelStreakReminderNotification" -> {
                        try {
                            cancelScheduledStreakReminderNotification()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CANCEL_STREAK_REMINDER_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "workout_native")
        workoutNativeAdFactory = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
