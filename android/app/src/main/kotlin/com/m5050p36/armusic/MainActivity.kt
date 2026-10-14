package com.m5050p36.armusic

import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.drawable.Icon
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
    private var inPipMode = false
    private var pipReceiver: BroadcastReceiver? = null

    // حالة عناصر التحكم — تُحدَّث من Flutter
    private var isPlaying = false
    private var hasNext = false
    private var hasPrev = false

    companion object {
        const val ACTION_PIP_PLAY_PAUSE = "com.m5050p36.armusic.PIP_PLAY_PAUSE"
        const val ACTION_PIP_NEXT = "com.m5050p36.armusic.PIP_NEXT"
        const val ACTION_PIP_PREV = "com.m5050p36.armusic.PIP_PREV"

        private const val RC_PLAY_PAUSE = 10
        private const val RC_NEXT = 11
        private const val RC_PREV = 12
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ════════════ PiP Channel ════════════
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PIP_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPiP" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                        result.success(false); return@setMethodCallHandler
                    }
                    try {
                        val w = call.argument<Int>("aspectRatioWidth") ?: 16
                        val h = call.argument<Int>("aspectRatioHeight") ?: 9
                        val params = buildPipParams(w, h)
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PIP_ERROR", e.message, null)
                    }
                }
                "updatePiPControls" -> {
                    isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    hasNext = call.argument<Boolean>("hasNext") ?: false
                    hasPrev = call.argument<Boolean>("hasPrev") ?: false

                    // حدّث الـ PiP فورًا إن كنا في وضعه
                    if (inPipMode && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            setPictureInPictureParams(buildPipParams(16, 9))
                        } catch (_: Exception) {}
                    }
                    result.success(true)
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

        // ════════════ Volume Boost Channel ════════════
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BOOST_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBoost" -> {
                    try {
                        val sessionId = call.argument<Int>("sessionId") ?: -1
                        val mB = call.argument<Int>("millibels") ?: 1500
                        if (sessionId < 0) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        loudness?.release()
                        loudness = LoudnessEnhancer(sessionId).apply {
                            setTargetGain(mB.coerceIn(0, 4000))
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

        // ════════════ PiP Broadcast Receiver ════════════
        registerPipReceiver(flutterEngine)
    }

    // ═══════════════════════════════════════════════════════
    // بناء PictureInPictureParams مع RemoteActions
    // ═══════════════════════════════════════════════════════
    private fun buildPipParams(w: Int, h: Int): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(w, h))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val actions = mutableListOf<RemoteAction>()

            // ─── السابق ───
            if (hasPrev) {
                actions.add(
                    makeAction(
                        android.R.drawable.ic_media_previous,
                        "السابق",
                        ACTION_PIP_PREV,
                        RC_PREV
                    )
                )
            }

            // ─── تشغيل/إيقاف ───
            actions.add(
                makeAction(
                    if (isPlaying) android.R.drawable.ic_media_pause
                    else android.R.drawable.ic_media_play,
                    if (isPlaying) "إيقاف مؤقت" else "تشغيل",
                    ACTION_PIP_PLAY_PAUSE,
                    RC_PLAY_PAUSE
                )
            )

            // ─── التالي ───
            if (hasNext) {
                actions.add(
                    makeAction(
                        android.R.drawable.ic_media_next,
                        "التالي",
                        ACTION_PIP_NEXT,
                        RC_NEXT
                    )
                )
            }

            builder.setActions(actions)
        }

        return builder.build()
    }

    private fun makeAction(
        iconRes: Int,
        title: String,
        action: String,
        requestCode: Int
    ): RemoteAction {
        val intent = Intent(action).setPackage(packageName)
        val pi = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )
        val icon = Icon.createWithResource(this, iconRes)
        return RemoteAction(icon, title, title, pi)
    }

    // ═══════════════════════════════════════════════════════
    // استقبال نقرات أزرار PiP وإرسالها إلى Flutter
    // ═══════════════════════════════════════════════════════
    private fun registerPipReceiver(flutterEngine: FlutterEngine) {
        pipReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return

                val method = when (action) {
                    ACTION_PIP_PLAY_PAUSE -> "onPiPPlayPause"
                    ACTION_PIP_NEXT -> "onPiPNext"
                    ACTION_PIP_PREV -> "onPiPPrev"
                    else -> null
                } ?: return

                // أرسل للـ Flutter
                try {
                    MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        PIP_CHANNEL
                    ).invokeMethod(method, null)
                } catch (_: Exception) {}
            }
        }

        val filter = IntentFilter().apply {
            addAction(ACTION_PIP_PLAY_PAUSE)
            addAction(ACTION_PIP_NEXT)
            addAction(ACTION_PIP_PREV)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipReceiver, filter)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        inPipMode = isInPictureInPictureMode
    }

    override fun onDestroy() {
        pipReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
        }
        pipReceiver = null
        loudness?.release()
        loudness = null
        super.onDestroy()
    }
}
