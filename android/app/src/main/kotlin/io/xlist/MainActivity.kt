package io.xlist

import android.app.PictureInPictureParams
import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
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
        // 这个 channel 只需 Dart -> native 单向调用，native 侧不回调，
        // 所以用局部变量即可（不需要持有引用）。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.xlist/system_ui").also {
                it.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getVolume" -> result.success(getSystemVolume())
                        "setVolume" -> {
                            val v = call.argument<Double>("volume") ?: 1.0
                            result.success(setSystemVolume(v.toFloat()))
                        }
                        "getBrightness" -> result.success(getScreenBrightness())
                        "setBrightness" -> {
                            val b = call.argument<Double>("brightness") ?: 1.0
                            setScreenBrightness(b.toFloat())
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
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
     * PiP 进出时通知 Flutter，让 UI 切换到纯视频布局
     * （PiP 窗口很小，不能保留右侧简介/播放列表栏）。
     */
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
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

    // ==================== 系统音量 / 屏幕亮度 ====================
    //
    // 这两项原本由已删除的 fijkplayer 插件提供（FijkVolume / FijkPlugin），
    // media_kit 迁移时未做替代，导致播放页左右半屏上下滑动手势失效。
    // 语义按 fijk 原样恢复：取值均归一化到 0.0–1.0。
    //
    // 都不需要运行时权限：
    //  - 窗口亮度是 per-activity（WindowManager.LayoutParams.screenBrightness），
    //    无需 WRITE_SETTINGS（那个只有写「系统」亮度才要）
    //  - 音量读写走 AudioManager.STREAM_MUSIC

    private fun audioManager(): AudioManager? =
        applicationContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager

    /** 当前媒体音量，0.0–1.0 */
    private fun getSystemVolume(): Double {
        val am = audioManager() ?: return 0.0
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        val vol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        return (vol.toDouble() / max.toDouble()).coerceIn(0.0, 1.0)
    }

    /** 设置媒体音量，[vol] 归一化 0.0–1.0；返回设置后的归一化值 */
    private fun setSystemVolume(vol: Float): Double {
        val am = audioManager() ?: return vol.toDouble()
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return 0.0
        var index = (vol * max).toInt()
        index = index.coerceIn(0, max)
        // 不弹系统音量条：播放器自带音量指示，系统条会与手势 UI 打架。
        am.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0)
        return index.toDouble() / max.toDouble()
    }

    /**
     * 当前屏幕亮度，0.0–1.0。
     *
     * 优先取本窗口的 screenBrightness（用户滑动过就是它）；
     * 为 -1 表示未设置、跟随系统，则回退读系统设置（读操作无需权限）。
     * 与 fijk 的实现一致。
     */
    private fun getScreenBrightness(): Double {
        val attrs = window?.attributes
        var brightness = attrs?.screenBrightness ?: -1f
        if (brightness < 0) {
            brightness =
                try {
                    Settings.System.getInt(
                        contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS,
                    ) / 255f
                } catch (e: Settings.SettingNotFoundException) {
                    Log.w(TAG, "system brightness not found, fallback to 1.0", e)
                    1.0f
                }
        }
        return brightness.toDouble().coerceIn(0.0, 1.0)
    }

    /** 设置当前窗口亮度，[brightness] 归一化 0.0–1.0 */
    private fun setScreenBrightness(brightness: Float) {
        val w = window ?: return
        val attrs = w.attributes
        attrs.screenBrightness = brightness.coerceIn(0f, 1f)
        w.attributes = attrs
    }
}
