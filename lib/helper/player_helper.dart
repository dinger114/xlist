import 'package:get/get.dart';

import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/x_player_track.dart';
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

    // HLS 专属优化
    if (name != null && name.toLowerCase().endsWith('.m3u8')) {
      await player.setProperty('cache-secs', '120');
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
