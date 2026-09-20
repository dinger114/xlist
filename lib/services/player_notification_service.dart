import 'dart:math';
import 'dart:async';

import 'package:get/get.dart';
import 'package:audio_service/audio_service.dart';

import 'package:xlist/constants/index.dart';
import 'package:xlist/pages/audio_player/index.dart';
import 'package:xlist/pages/video_player/index.dart';
import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/x_player_state.dart';

// PlayerNotificationService https://pub.dev/packages/audio_service
class PlayerNotificationService extends GetxService {
  static PlayerNotificationService get to => Get.find();

  late PlayerNotificationHandler _audioHandler;
  PlayerNotificationHandler get audioHandler => _audioHandler;

  // Init
  Future<PlayerNotificationService> init() async {
    _audioHandler = await AudioService.init(
      builder: () => PlayerNotificationHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'io.xlist.channel.audio',
        androidNotificationChannelName: 'Xlist playback',
        androidNotificationOngoing: true,
        rewindInterval: const Duration(seconds: 15),
        fastForwardInterval: const Duration(seconds: 15),
      ),
    );
    return this;
  }
}

class PlayerNotificationHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  late StreamController<PlaybackState> streamController;

  // XPlayerState → audio_service state
  static final X_TO_PROCESSING_STATE = {
    XPlayerState.idle: AudioProcessingState.idle,
    XPlayerState.loading: AudioProcessingState.buffering,
    XPlayerState.ready: AudioProcessingState.ready,
    XPlayerState.playing: AudioProcessingState.ready,
    XPlayerState.paused: AudioProcessingState.ready,
    XPlayerState.buffering: AudioProcessingState.buffering,
    XPlayerState.stopped: AudioProcessingState.ready,
    XPlayerState.error: AudioProcessingState.error,
    XPlayerState.completed: AudioProcessingState.completed,
  };

  Function? _play;
  Function? _pause;
  Function? _seek;
  Function? _stop;

  bool? _isVideo;
  bool? _isPlaylist;
  XPlayer? _player;
  final List<StreamSubscription> _subs = [];

  void setVideoFunctions(
      Function play, Function pause, Function seek, Function stop) {
    _play = play;
    _pause = pause;
    _seek = seek;
    _stop = stop;
  }

  /// Initialise our audio handler.
  PlayerNotificationHandler();

  @override
  Future<void> play() async => _play!();

  @override
  Future<void> pause() async => _pause!();

  @override
  Future<void> seek(Duration position) async => _seek!(position.inMilliseconds);

  @override
  Future<void> stop() async => _stop!();

  @override
  Future<void> skipToPrevious() async {
    try {
      if (!_isPlaylist!) return;

      // Get the current video/audio player controller.
      dynamic _vp = _isVideo ?? false
          ? Get.find<VideoPlayerController>()
          : Get.find<AudioPlayerController>();

      // If the current play mode is shuffle, change the playlist to a random index.
      final _playMode =
          _isVideo ?? false ? _vp.playMode.val : _vp.playMode.value;
      if (_playMode == PlayMode.SHUFFLE) {
        _vp.changePlaylist(Random().nextInt(_vp.objects.length));
        return;
      }

      // Change the current index to the previous index.
      _vp.currentIndex.value == 0
          ? _vp.changePlaylist(_vp.objects.length - 1)
          : _vp.changePlaylist(_vp.currentIndex.value - 1);
    } catch (e) {}
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (!_isPlaylist!) return;

      // Get the current video/audio player controller.
      dynamic _vp = _isVideo ?? false
          ? Get.find<VideoPlayerController>()
          : Get.find<AudioPlayerController>();

      // If the current play mode is shuffle, change the playlist to a random index.
      final _playMode =
          _isVideo ?? false ? _vp.playMode.val : _vp.playMode.value;
      if (_playMode == PlayMode.SHUFFLE) {
        _vp.changePlaylist(Random().nextInt(_vp.objects.length));
        return;
      }

      // Change the current index to the next index.
      _vp.currentIndex.value == _vp.objects.length - 1
          ? _vp.changePlaylist(0)
          : _vp.changePlaylist(_vp.currentIndex.value + 1);
    } catch (e) {}
  }

  /// Initialise our stream controller and start listening to player events.
  /// [player] is the XPlayer instance.
  void initializeStreamController(
      XPlayer player, bool isPlaylist, bool isVideo) {
    _isVideo = isVideo;
    _isPlaylist = isPlaylist;
    _player = player;

    void startStream() {
      _subs.add(player.stateStream.listen((_) => updatePlaybackState()));
      _subs.add(player.playingStream.listen((_) => updatePlaybackState()));
      _subs.add(player.positionStream.listen((_) => updatePlaybackState()));
      _subs.add(player.bufferStream.listen((_) => updatePlaybackState()));
    }

    void stopStream() {
      for (final sub in _subs) {
        sub.cancel();
      }
      _subs.clear();
      streamController.close();
    }

    // Start the stream
    streamController = StreamController<PlaybackState>(
      onListen: startStream,
      onPause: stopStream,
      onResume: startStream,
      onCancel: stopStream,
    );
  }

  /// Broadcast playback state.
  void updatePlaybackState([_]) {
    final player = _player;
    if (player == null) return;

    // stopStream() 在最后一个监听者取消时会 close() 这个 controller，
    // 但调用方（如 audio_player/controller.dart 的 playingStream 监听）
    // 会用 Future.delayed 延迟 1s 再回调进来。等定时器触发时 controller
    // 可能已经关闭，此时 add() 会抛 "Bad state: Cannot add event after
    // closing"（表现为关闭播放器后日志里的未捕获异常）。提前退出。
    if (streamController.isClosed) return;

    AudioProcessingState _processingState() {
      if (player.isBuffering) return AudioProcessingState.buffering;
      return X_TO_PROCESSING_STATE[player.state] ?? AudioProcessingState.idle;
    }

    streamController.add(PlaybackState(
      controls: [
        _isPlaylist ?? false
            ? MediaControl.skipToPrevious
            : MediaControl.rewind,
        if (player.isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        _isPlaylist ?? false
            ? MediaControl.skipToNext
            : MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _processingState(),
      playing: player.isPlaying,
      updatePosition: player.position,
      bufferedPosition: player.buffer,
      speed: 1.0,
    ));
  }
}
