package com.m5050p36.armusic

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    private val PIP_CHANNEL = "com.m5050p36.armusic/pip"
    private val BOOST_CHANNEL = "com.m5050p36.armusic/volume_boost"

    private var loudness: LoudnessEnhancer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ═══ PiP ═══
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PIP_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val width = call.argument<Int>("aspectRatioWidth") ?: 16
                        val height = call.argument<Int>("aspectRatioHeight") ?: 9
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(width, height))
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PIP_ERROR", e.message, null)
                    }
                }
                "isPiPSupported" -> {
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(
                                PackageManager.FEATURE_PICTURE_IN_PICTURE
                            )
                    result.success(supported)
                }
                else -> result.notImplemented()
            }
        }

        // ═══ Volume Boost (LoudnessEnhancer) ═══
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOST_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBoost" -> {
                    try {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        val millibels = call.argument<Int>("millibels") ?: 1500
                        if (sessionId <= 0) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        loudness?.release()
                        loudness = LoudnessEnhancer(sessionId).apply {
                            setTargetGain(millibels.coerceIn(0, 4000))
                            enabled = true
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BOOST_ERROR", e.message, null)
                    }
                }
                "disableBoost" -> {
                    try {
                        loudness?.enabled = false
                        loudness?.release()
                        loudness = null
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }

    override fun onDestroy() {
        loudness?.release()
        loudness = null
        super.onDestroy()
    }
}
