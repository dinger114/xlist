import 'package:get/get.dart';

import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/media_kit_player.dart';
import 'package:xlist/core/player/x_video_controller.dart';
import 'package:xlist/storages/index.dart';

export 'package:xlist/core/player/x_player.dart';
export 'package:xlist/core/player/x_player_state.dart';
export 'package:xlist/core/player/x_player_track.dart';
export 'package:xlist/core/player/media_kit_player.dart';
export 'package:xlist/core/player/x_video_controller.dart';

/// 播放器工厂：业务层统一从这里创建播放器
XPlayer createXPlayer({bool isVideo = true}) {
  final player = MediaKitPlayer();
  return player;
}

/// media_kit 视图控制器工厂
XVideoController createXVideoController(MediaKitPlayer player) {
  return XVideoController(player);
}

/// Player Helper（替换 FijkHelper）
/// [PlayerHelper]
class PlayerHelper {
  /// 设置播放器选项（替代 FijkHelper.setFijkOption）
  /// [player] XPlayer 实例
  /// [isAudioOnly] 是否仅音频
  /// [name] 文件名（判断是否 HLS）
  /// [headers] HTTP headers
  static Future<void> setOption(
    XPlayer player, {
    bool isAudioOnly = false,
    String? name,
    Map<String, String>? headers,
  }) async {
    // 硬件解码
    final isHardwareDecode =
        Get.find<PreferencesStorage>().isHardwareDecode.val;
    await player.setHardwareDecode(isHardwareDecode);

    // 通用 mpv 优化
    await player.setProperty('framedrop', 'vo');
    await player.setProperty('audio-pitch-correction', 'yes');
    await player.setProperty('network-timeout', '30');
    await player.setProperty('cache', 'yes');
    await player.setProperty('demuxer-max-bytes', '50MiB');
    await player.setProperty('demuxer-max-back-bytes', '20MiB');

    // 音频模式不渲染视频
    if (isAudioOnly) await player.setProperty('vid', 'no');

    // HLS
    //
    // 原为 `cache-secs = 120`，实测在 alist 的 HLS 上会长时间转圈：
    // 该站点的 m3u8 分段是 ~22.5MB / 60s（约 3Mbps），120s 即需预缓冲
    // 约 45MB，逼近 `demuxer-max-bytes` 的 50MiB 上限，mpv 会一直等缓存
    // 填满才开播；若换成码率更高的源（120s > 50MiB），缓存永远填不满，
    // 表现为**一直转圈加载不出来**。
    // 这里收敛到「缓存目标」与「缓存上限」相称的取值：20s ≈ 7.5MB，
    // 远小于上限，起播快；同时不放宽上限以免占用过多内存。
    if (name != null && name.toLowerCase().endsWith('.m3u8')) {
      await player.setProperty('cache-secs', '20');
      await player.setProperty('cache-pause', 'yes');
      await player.setProperty('cache-pause-wait', '3');
    }

    // Headers 在 open(Media(httpHeaders:)) 时传入，这里无需设置
  }

  /// 播放器时间转字符串
  /// [duration]
  static String formatDuration(Duration duration) {
    if (duration.inMilliseconds < 0) return "-: negtive";

    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    int inHours = duration.inHours;
    return inHours > 0
        ? '$inHours:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }
}
