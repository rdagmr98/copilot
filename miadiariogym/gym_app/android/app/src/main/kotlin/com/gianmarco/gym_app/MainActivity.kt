package com.gianmarco.gym_app

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
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
                    else -> result.notImplemented()
                }
            }
    }
}
