import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/constants/index.dart';
import 'package:xlist/services/audio_player_service.dart';

/// `nextActionOnCompleted` 的单元测试。
///
/// 背景：播放器从播放页 controller 搬进全局 AudioPlayerService 时，把「播完
/// 该干什么」抽成了纯函数。这是整套逻辑里最容易错的一环 —— 原实现里队列只有
/// 一首时会无限切歌，而「播完暂停」与「单曲循环」都返回 null 也分不开。
void main() {
  group('播完后的动作', () {
    test('单曲队列：任何模式都原地重播（避免无限切歌）', () {
      for (final mode in [
        PlayMode.listLoop,
        PlayMode.singleLoop,
        PlayMode.shuffle,
        PlayMode.playPause,
      ]) {
        final action = nextActionOnCompleted(
          currentIndex: 0,
          queueLength: 1,
          playMode: mode,
        );
        expect(action.replayInPlace, isTrue, reason: '模式 $mode 下单曲队列应原地重播');
        expect(action.nextIndex, isNull);
      }
    });

    test('单曲循环：原地重播（不是 stop）', () {
      final action = nextActionOnCompleted(
        currentIndex: 3,
        queueLength: 10,
        playMode: PlayMode.singleLoop,
      );
      expect(action.replayInPlace, isTrue);
      expect(action.nextIndex, isNull);
    });

    test('列表循环：顺序前进', () {
      expect(
        nextActionOnCompleted(
          currentIndex: 0,
          queueLength: 5,
          playMode: PlayMode.listLoop,
        ).nextIndex,
        1,
      );
      expect(
        nextActionOnCompleted(
          currentIndex: 3,
          queueLength: 5,
          playMode: PlayMode.listLoop,
        ).nextIndex,
        4,
      );
    });

    test('列表循环：最后一首回到第一首', () {
      expect(
        nextActionOnCompleted(
          currentIndex: 4,
          queueLength: 5,
          playMode: PlayMode.listLoop,
        ).nextIndex,
        0,
      );
    });

    test('随机：使用注入的随机值（不依赖真随机）', () {
      expect(
        nextActionOnCompleted(
          currentIndex: 0,
          queueLength: 10,
          playMode: PlayMode.shuffle,
          randomPicker: (len) => 7,
        ).nextIndex,
        7,
      );
    });

    test('随机：抽到当前这首也返回该下标（由调用方 allowSameIndex 放行）', () {
      expect(
        nextActionOnCompleted(
          currentIndex: 3,
          queueLength: 10,
          playMode: PlayMode.shuffle,
          randomPicker: (len) => 3,
        ).nextIndex,
        3,
      );
    });

    test('播完暂停：既不在原地重播，也不切歌（必须真的停住）', () {
      final action = nextActionOnCompleted(
        currentIndex: 0,
        queueLength: 5,
        playMode: PlayMode.playPause,
      );
      expect(action.replayInPlace, isFalse);
      expect(action.nextIndex, isNull);
    });

    test('未知模式：按停住处理，不抛异常', () {
      final action = nextActionOnCompleted(
        currentIndex: 0,
        queueLength: 5,
        playMode: 99,
      );
      expect(action.replayInPlace, isFalse);
      expect(action.nextIndex, isNull);
    });

    test('空队列：原地重播分支不进，不抛异常', () {
      final action = nextActionOnCompleted(
        currentIndex: 0,
        queueLength: 0,
        playMode: PlayMode.listLoop,
      );
      // queueLength <= 1 走原地重播；调用方会因为 player 没源而自然无事发生
      expect(action.replayInPlace, isTrue);
    });

    test('兼容旧签名的 nextIndexOnCompleted 行为一致', () {
      expect(
        nextIndexOnCompleted(
          currentIndex: 0,
          queueLength: 5,
          playMode: PlayMode.listLoop,
        ),
        nextActionOnCompleted(
          currentIndex: 0,
          queueLength: 5,
          playMode: PlayMode.listLoop,
        ).nextIndex,
      );
      // 单曲循环在旧签名下同样是 null（调用方需靠 replayInPlace 区分）
      expect(
        nextIndexOnCompleted(
          currentIndex: 0,
          queueLength: 5,
          playMode: PlayMode.singleLoop,
        ),
        isNull,
      );
    });
  });
}
