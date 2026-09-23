import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'x_player.dart';
import 'x_player_state.dart';
import 'x_player_track.dart';

/// mpv 后端日志开关：`--dart-define=XLIST_MPV_LOG=true`。
///
/// 排查「转圈 / 加载不出来」这类播放故障时，media_kit 自身的诊断信息
/// 在 release 下会被丢弃（走 print），mpv 的日志也默认不暴露，导致只能靠猜。
/// 打开后把 mpv 原始日志经 debugPrint 打到 logcat（`adb logcat | grep XLIST_MPV`）。
/// 与 `Global.routeLog` 同思路：release 包也能开，平时零开销。
const bool _mpvLog = bool.fromEnvironment('XLIST_MPV_LOG');

/// media_kit 实现的 XPlayer
class MediaKitPlayer implements XPlayer {
  final Player _player;
  Player get rawPlayer => _player;

  // 内部状态缓存
  XPlayerState _state = XPlayerState.idle;
  Duration _position = Duration.zero;
  Duration _buffer = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isBuffering = false;
  List<XTrack> _tracks = [];
  XTrackSelection _trackSelection = const XTrackSelection();

  // 广播流
  final StreamController<XPlayerState> _stateController =
      StreamController<XPlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _bufferController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _bufferingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _completedController =
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<List<XTrack>> _tracksController =
      StreamController<List<XTrack>>.broadcast();
  final StreamController<XTrackSelection> _trackSelectionController =
      StreamController<XTrackSelection>.broadcast();

  final List<StreamSubscription> _subscriptions = [];

  MediaKitPlayer({PlayerConfiguration? configuration})
    : _player = Player(
        configuration:
            configuration ??
            PlayerConfiguration(
              // 仅在 XLIST_MPV_LOG 打开时提高 mpv 日志级别，
              // 正常构建保持默认（error），无额外开销。
              logLevel: _mpvLog ? MPVLogLevel.info : MPVLogLevel.error,
            ),
      ) {
    _initListeners();
  }

  void _initListeners() {
    // mpv 后端日志（仅 XLIST_MPV_LOG 时输出）。排查播放故障的第一手证据：
    // 「转圈」多数是 hls 缓存/网络层的问题，只有 mpv 自己的日志说得清。
    if (_mpvLog) {
      _subscriptions.add(
        _player.stream.log.listen((log) {
          debugPrint('XLIST_MPV [${log.level}] ${log.prefix}: ${log.text}');
        }),
      );
    }

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        _isPlaying = playing;
        _playingController.add(playing);
        if (playing) {
          _updateState(XPlayerState.playing);
        } else if (_state != XPlayerState.completed) {
          _updateState(XPlayerState.paused);
        }
      }),
    );

    _subscriptions.add(
      _player.stream.position.listen((pos) {
        _position = pos;
        _positionController.add(pos);
      }),
    );

    _subscriptions.add(
      _player.stream.buffer.listen((buf) {
        _buffer = buf;
        _bufferController.add(buf);
      }),
    );

    _subscriptions.add(
      _player.stream.duration.listen((dur) {
        _duration = dur;
        _durationController.add(dur);
      }),
    );

    _subscriptions.add(
      _player.stream.buffering.listen((buf) {
        _isBuffering = buf;
        _bufferingController.add(buf);
        if (buf) {
          _updateState(XPlayerState.buffering);
        } else if (_isPlaying) {
          _updateState(XPlayerState.playing);
        }
      }),
    );

    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        _completedController.add(completed);
        if (completed) _updateState(XPlayerState.completed);
      }),
    );

    _subscriptions.add(
      _player.stream.error.listen((err) {
        _errorController.add(err);
        _updateState(XPlayerState.error);
      }),
    );

    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        final all = <XTrack>[
          ...tracks.audio.map((t) => _convertTrack(t, XTrackType.audio)),
          ...tracks.video.map((t) => _convertTrack(t, XTrackType.video)),
          ...tracks.subtitle.map((t) => _convertTrack(t, XTrackType.subtitle)),
        ].where((t) => !t.isNone).toList();
        _tracks = all;
        _tracksController.add(all);
      }),
    );

    _subscriptions.add(
      _player.stream.track.listen((track) {
        _trackSelection = XTrackSelection(
          audio: track.audio.id != 'no' && track.audio.id != 'auto'
              ? _convertTrack(track.audio, XTrackType.audio)
              : null,
          video: track.video.id != 'no' && track.video.id != 'auto'
              ? _convertTrack(track.video, XTrackType.video)
              : null,
          subtitle: track.subtitle.id != 'no' && track.subtitle.id != 'auto'
              ? _convertTrack(track.subtitle, XTrackType.subtitle)
              : null,
        );
        _trackSelectionController.add(_trackSelection);
      }),
    );
  }

  void _updateState(XPlayerState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  // 参数只能不写类型：AudioTrack/VideoTrack/SubtitleTrack 的公共基类 _Track 是
  // media_kit 的私有类型，包外引用不到；公开的 `Track` 是另一个不相关类型。
  // ignore: strict_top_level_inference
  XTrack _convertTrack(t, XTrackType type) {
    return XTrack(id: t.id, type: type, title: t.title, language: t.language);
  }

  // ============ Snapshots ============
  @override
  XPlayerState get state => _state;
  @override
  Duration get position => _position;
  @override
  Duration get buffer => _buffer;
  @override
  Duration get duration => _duration;
  @override
  bool get isPlaying => _isPlaying;
  @override
  bool get isBuffering => _isBuffering;
  @override
  List<XTrack> get tracks => _tracks;
  @override
  XTrackSelection get trackSelection => _trackSelection;

  // ============ Streams ============
  @override
  Stream<XPlayerState> get stateStream => _stateController.stream;
  @override
  Stream<Duration> get positionStream => _positionController.stream;
  @override
  Stream<Duration> get bufferStream => _bufferController.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;
  @override
  Stream<Duration> get durationStream => _durationController.stream;
  @override
  Stream<bool> get playingStream => _playingController.stream;
  @override
  Stream<bool> get completedStream => _completedController.stream;
  @override
  Stream<String> get errorStream => _errorController.stream;
  @override
  Stream<List<XTrack>> get tracksStream => _tracksController.stream;
  @override
  Stream<XTrackSelection> get trackSelectionStream =>
      _trackSelectionController.stream;

  // ============ Controls ============
  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoPlay = true,
  }) async {
    _updateState(XPlayerState.loading);
    final media = Media(url, httpHeaders: headers ?? const {});
    await _player.open(media, play: autoPlay);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> setRate(double rate) => _player.setRate(rate);
  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setAudioTrack(XTrack track) async {
    final raw = _player.state.tracks.audio.whereType<AudioTrack>().firstWhere(
      (t) => t.id == track.id,
      orElse: () => AudioTrack.no(),
    );
    await _player.setAudioTrack(raw);
  }

  @override
  Future<void> setSubtitleTrack(XTrack? track) async {
    if (track == null || track.isNone) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final raw = _player.state.tracks.subtitle
        .whereType<SubtitleTrack>()
        .firstWhere((t) => t.id == track.id, orElse: () => SubtitleTrack.no());
    await _player.setSubtitleTrack(raw);
  }

  // ============ Configuration ============
  @override
  Future<void> setHardwareDecode(bool enabled) async {
    final impl = _player.platform;
    if (impl is! NativePlayer) return;
    await impl.setProperty('hwdec', enabled ? 'auto-safe' : 'no');
  }

  @override
  Future<void> setProperty(String key, String value) async {
    final impl = _player.platform;
    if (impl is! NativePlayer) return;
    await impl.setProperty(key, value);
  }

  // ============ Lifecycle ============
  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _stateController.close();
    await _positionController.close();
    await _bufferController.close();
    await _bufferingController.close();
    await _durationController.close();
    await _playingController.close();
    await _completedController.close();
    await _errorController.close();
    await _tracksController.close();
    await _trackSelectionController.close();
    await _player.dispose();
  }
}
