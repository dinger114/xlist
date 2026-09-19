package io.xlist

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        const val PIP_ASPECT_WIDTH = 16
        const val PIP_ASPECT_HEIGHT = 9
    }

    private var pipEligible = false
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.xlist/pip").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipEligible" -> {
                        pipEligible = call.argument<Boolean>("eligible") ?: false
                        result.success(true)
                    }
                    "enterPip" -> {
                        enterPipMode()
                        result.success(true)
                    }
                    "isPipAvailable" -> {
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // 用户按 Home 键离开时，若正在播放视频则自动进入画中画
        if (pipEligible) {
            enterPipMode()
        }
    }

    private fun enterPipMode() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(PIP_ASPECT_WIDTH, PIP_ASPECT_HEIGHT))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
        }
    }
}
