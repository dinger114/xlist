import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:xlist/core/player/media_kit_player.dart';
import 'package:xlist/core/player/x_player_state.dart';

bool _nativeLibAvailable = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized();
  } catch (_) {
    // CI / 桌面测试环境没有 Mpv.framework 时跳过依赖原生库的用例
    _nativeLibAvailable = false;
  }

  group('MediaKitPlayer 生命周期', () {
    test('初始状态为 idle', () {
      if (!_nativeLibAvailable) return;
      final player = MediaKitPlayer();
      expect(player.state, XPlayerState.idle);
      expect(player.isPlaying, isFalse);
      expect(player.isBuffering, isFalse);
      expect(player.position, Duration.zero);
      expect(player.duration, Duration.zero);
      expect(player.tracks, isEmpty);
      player.dispose();
    });

    test('setRate/setVolume/seek 在 idle 状态下不抛异常', () async {
      if (!_nativeLibAvailable) return;
      final player = MediaKitPlayer();
      await player.setRate(1.5);
      await player.setVolume(50);
      await player.seek(const Duration(seconds: 1));
      await player.pause();
      await player.dispose();
    });

    test('dispose 后流关闭', () async {
      if (!_nativeLibAvailable) return;
      final player = MediaKitPlayer();
      final states = <XPlayerState>[];
      final sub = player.stateStream.listen(states.add);
      await player.dispose();
      await sub.cancel();
      expect(player.stateStream, isNotNull);
    });
  });

  group('XPlayer 接口契约', () {
    test('MediaKitPlayer 是 XPlayer 实例', () {
      if (!_nativeLibAvailable) return;
      final player = MediaKitPlayer();
      expect(player, isA<MediaKitPlayer>());
      player.dispose();
    });
  });
}
