import 'package:media_kit_video/media_kit_video.dart';

import 'media_kit_player.dart';

/// media_kit 视图控制器封装
class XVideoController {
  late final VideoController _controller;
  VideoController get raw => _controller;

  XVideoController(MediaKitPlayer player) {
    _controller = VideoController(player.rawPlayer);
  }
}
