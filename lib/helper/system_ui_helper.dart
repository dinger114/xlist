import 'package:flutter/services.dart';

/// 系统音量 / 屏幕亮度控制（播放页左右半屏上下滑动调节）。
///
/// 为什么需要它：media_kit 迁移（`d635029`）之前，这两项能力由 fijkplayer
/// 插件提供 —— `FijkVolume`（系统音量，`STREAM_MUSIC`）与 `FijkPlugin`
/// （当前窗口亮度）。迁移时整个 fijkplayer 包被删除，但**没有做替代**：
///
///   1. `_onVerticalDragUpdate` 里的**亮度分支整段消失**（左半屏上下滑完全无反应）
///   2. 音量从「系统音量」换成了 `player.setVolume()`（mpv 内部音量），
///      且初值读取（`FijkVolume.getVol()`）被写死成 `1.0` —— 一上手就跳满
///
/// 这里按 fijk 的原语义补回：取值都是 0.0–1.0，作用于**系统音量**与
/// **当前窗口亮度**（不是播放器自身的 volume 属性）。
///
/// 两者都不需要运行时权限：窗口亮度是 per-activity 的
/// `WindowManager.LayoutParams.screenBrightness`；系统音量读写走
/// `AudioManager.STREAM_MUSIC`。回退读取 `Settings.System.SCREEN_BRIGHTNESS`
/// 也无需权限（只有写入系统亮度才要 `WRITE_SETTINGS`）。
class SystemUiHelper {
  static const MethodChannel _channel = MethodChannel('io.xlist/system_ui');

  /// 当前系统媒体音量，0.0–1.0。
  static Future<double> getVolume() async {
    final v = await _channel.invokeMethod<double>('getVolume');
    return (v ?? 0.0).clamp(0.0, 1.0);
  }

  /// 设置系统媒体音量，[volume] 取值 0.0–1.0。
  static Future<void> setVolume(double volume) async {
    await _channel.invokeMethod<void>('setVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// 当前屏幕亮度，0.0–1.0。
  static Future<double> getBrightness() async {
    final v = await _channel.invokeMethod<double>('getBrightness');
    return (v ?? 0.0).clamp(0.0, 1.0);
  }

  /// 设置当前窗口亮度，[brightness] 取值 0.0–1.0。
  static Future<void> setBrightness(double brightness) async {
    await _channel.invokeMethod<void>('setBrightness', {
      'brightness': brightness.clamp(0.0, 1.0),
    });
  }
}
