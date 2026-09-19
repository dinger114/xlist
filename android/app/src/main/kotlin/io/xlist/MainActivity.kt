package io.xlist

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Log
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "XlistPip"
        const val PIP_ASPECT_WIDTH = 16
        const val PIP_ASPECT_HEIGHT = 9
    }

    private var pipEligible = false
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.xlist/pip").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPipEligible" -> {
                        pipEligible = call.argument<Boolean>("eligible") ?: false
                        syncPipParams()
                        result.success(true)
                    }
                    "enterPip" -> {
                        val w = call.argument<Double>("ratioW") ?: PIP_ASPECT_WIDTH.toDouble()
                        val h = call.argument<Double>("ratioH") ?: PIP_ASPECT_HEIGHT.toDouble()
                        result.success(enterPipMode(w, h))
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
        // API 31+ 由 setAutoEnterEnabled 负责过渡动画，这里只兜底旧版本。
        if (pipEligible && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPipMode()
        }
    }

    /**
     * 把当前 PiP 参数同步给系统。
     * API 31+ 用 setAutoEnterEnabled，Home 手势由系统直接接管（无跳变）；
     * 参数必须在每次变化时重新提交，否则系统沿用旧值。
     */
    private fun syncPipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val builder = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(PIP_ASPECT_WIDTH, PIP_ASPECT_HEIGHT))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setAutoEnterEnabled(pipEligible)
            }
            setPictureInPictureParams(builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "syncPipParams failed", e)
        }
    }

    /** @return 是否成功进入 PiP */
    private fun enterPipMode(
        ratioW: Double = PIP_ASPECT_WIDTH.toDouble(),
        ratioH: Double = PIP_ASPECT_HEIGHT.toDouble(),
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.w(TAG, "PiP requires API 26+")
            return false
        }
        if (isInPictureInPictureMode) return true
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(
                    Rational((ratioW * 100).toInt(), (ratioH * 100).toInt())
                )
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            // 常见原因：manifest 缺 supportsPictureInPicture，或 Activity 不在前台。
            // 不要静默吞掉，否则按钮「点了没反应」无从排查。
            Log.e(TAG, "enterPipMode failed", e)
            false
        }
    }
}
