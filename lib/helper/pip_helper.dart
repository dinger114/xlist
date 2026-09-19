import 'dart:async';

import 'package:flutter/services.dart';

/// Android 画中画 (PiP) 控制
///
/// 原生侧在 onUserLeaveHint 时根据 pipEligible 决定是否自动进入 PiP；
/// Flutter 侧通过 [PipHelper.setPipEligible] 标记视频播放页是否允许 PiP。
class PipHelper {
  static const MethodChannel _channel = MethodChannel('io.xlist/pip');

  static bool? _available;

  /// PiP 是否可用（Android 8.0+）
  static Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('isPipAvailable') ?? false;
    } catch (e) {
      _available = false;
    }
    return _available!;
  }

  /// 标记当前页面是否允许在离开时自动进入 PiP
  static Future<void> setPipEligible(bool eligible) async {
    if (!await isAvailable) return;
    try {
      await _channel.invokeMethod('setPipEligible', {'eligible': eligible});
    } catch (e) {
      // channel 未就绪时忽略
    }
  }

  /// 手动进入画中画
  static Future<void> enterPip() async {
    if (!await isAvailable) return;
    try {
      await _channel.invokeMethod('enterPip');
    } catch (e) {}
  }

  /// 视频播放页进入时调用
  static Future<void> onVideoPageEnter() => setPipEligible(true);

  /// 视频播放页退出时调用
  static Future<void> onVideoPageExit() => setPipEligible(false);
}
