import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/x_player_track.dart';
import 'package:xlist/services/player_notification_service.dart';

/// PlayerNotificationHandler.updatePlaybackState 的回归测试。
///
/// 背景：stopStream() 在最后一个监听者取消时会 close() streamController，
/// 但调用方（audio_player/controller.dart 的 playingStream 监听）用
/// Future.delayed(1s) 延迟回调进来。定时器触发时 controller 可能已关闭，
/// 此时 add() 抛 "Bad state: Cannot add event after closing" —— 真机上表现
/// 为关闭播放器后日志里的未捕获异常。
///
/// 修复：updatePlaybackState 开头判断 isClosed 提前返回。
void main() {
  group('PlayerNotificationHandler 关闭后回调', () {
    test('controller 关闭后再 updatePlaybackState 不抛异常（回归）', () async {
      final handler = PlayerNotificationHandler();
      handler.initializeStreamController(_FakeXPlayer(), false, false);

      // 模拟 stopStream()：关闭 controller。
      // 注意不能 await —— close() 的 Future 在无监听者时不会 complete
      // （done 事件投递不出去），await 会让测试挂住。isClosed 调用后即生效。
      unawaited(handler.streamController.close());

      // 修复前：Bad state: Cannot add event after closing
      expect(handler.updatePlaybackState, returnsNormally);
    });

    test('关闭后多次调用也安全（定时器可能重复触发）', () async {
      final handler = PlayerNotificationHandler();
      handler.initializeStreamController(_FakeXPlayer(), false, false);
      unawaited(handler.streamController.close());

      for (var i = 0; i < 5; i++) {
        expect(handler.updatePlaybackState, returnsNormally);
      }
    });

    test('未关闭时正常发出 PlaybackState（确认没改坏正常路径）', () async {
      final handler = PlayerNotificationHandler();
      handler.initializeStreamController(_FakeXPlayer(), false, false);

      final received = <PlaybackState>[];
      final sub = handler.streamController.stream.listen(received.add);

      handler.updatePlaybackState();
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first.playing, isFalse);
      expect(received.first.processingState, isNotNull);

      await sub.cancel();
      await handler.streamController.close();
    });

    test('_player 为 null 时直接返回（未初始化不得崩）', () {
      final handler = PlayerNotificationHandler();
      // 未调用 initializeStreamController 就回调
      expect(() => handler.updatePlaybackState(), returnsNormally);
    });
  });
}

/// 最小 XPlayer 假实现：只需支撑 updatePlaybackState 读取的快照字段
class _FakeXPlayer implements XPlayer {
  final _stateCtrl = StreamController<XPlayerState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _durCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _tracksCtrl = StreamController<List<XTrack>>.broadcast();
  final _selCtrl = StreamController<XTrackSelection>.broadcast();

  @override
  Stream<XPlayerState> get stateStream => _stateCtrl.stream;
  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get bufferStream => _bufCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<Duration> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<bool> get completedStream => _completedCtrl.stream;
  @override
  Stream<String> get errorStream => _errorCtrl.stream;
  @override
  Stream<List<XTrack>> get tracksStream => _tracksCtrl.stream;
  @override
  Stream<XTrackSelection> get trackSelectionStream => _selCtrl.stream;

  @override
  XPlayerState get state => XPlayerState.idle;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get buffer => Duration.zero;
  @override
  Duration get duration => Duration.zero;
  @override
  bool get isPlaying => false;
  @override
  bool get isBuffering => false;
  @override
  List<XTrack> get tracks => const [];
  @override
  XTrackSelection get trackSelection => XTrackSelection();

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoPlay = true,
  }) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setAudioTrack(XTrack track) async {}
  @override
  Future<void> setSubtitleTrack(XTrack? track) async {}
  @override
  Future<void> setHardwareDecode(bool enabled) async {}
  @override
  Future<void> setProperty(String key, String value) async {}

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
    await _posCtrl.close();
    await _bufCtrl.close();
    await _bufferingCtrl.close();
    await _durCtrl.close();
    await _playingCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
    await _tracksCtrl.close();
    await _selCtrl.close();
  }
}
