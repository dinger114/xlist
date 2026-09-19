import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 画中画 (PiP) 控制
///
/// 原生侧在 onUserLeaveHint 时根据 pipEligible 决定是否自动进入 PiP；
/// Flutter 侧通过 [PipHelper.setPipEligible] 标记视频播放页是否允许 PiP。
class PipHelper {
  static const MethodChannel _channel = MethodChannel('io.xlist/pip');

  static bool? _available;

  /// PiP 进出通知（原生 onPictureInPictureModeChanged 回调）。
  /// true = 已进入 PiP，false = 已退出。
  static final StreamController<bool> _pipChangedController =
      StreamController<bool>.broadcast();

  /// 监听 PiP 进出，用于切换纯视频布局
  static Stream<bool> get onPipChanged => _pipChangedController.stream;

  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        _pipChangedController.add(call.arguments == true);
      }
      return null;
    });
  }

  /// PiP 是否可用（Android 8.0+）
  static Future<bool> get isAvailable async {
    _ensureHandler();
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('isPipAvailable') ?? false;
    } catch (e) {
      debugPrint('[PipHelper] isPipAvailable failed: $e');
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
      debugPrint('[PipHelper] setPipEligible failed: $e');
    }
  }

  /// 手动进入画中画
  ///
  /// 返回是否成功。失败原因（manifest 未声明 supportsPictureInPicture、
  /// Activity 不在前台等）由原生侧记入 logcat，tag 为 `XlistPip`。
  static Future<bool> enterPip() async {
    if (!await isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('enterPip') ?? false;
    } catch (e) {
      debugPrint('[PipHelper] enterPip failed: $e');
      return false;
    }
  }

  /// 视频播放页进入时调用
  static Future<void> onVideoPageEnter() => setPipEligible(true);

  /// 视频播放页退出时调用
  static Future<void> onVideoPageExit() => setPipEligible(false);
}
