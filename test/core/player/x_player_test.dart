import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/x_player_track.dart';

void main() {
  group('XPlayerState', () {
    test('包含所有预期状态', () {
      const states = [
        XPlayerState.idle,
        XPlayerState.loading,
        XPlayerState.ready,
        XPlayerState.buffering,
        XPlayerState.playing,
        XPlayerState.paused,
        XPlayerState.completed,
        XPlayerState.error,
        XPlayerState.stopped,
      ];
      expect(states.toSet().length, states.length);
    });
  });

  group('XTrack', () {
    test('XTrack.none 是关闭字幕占位轨道', () {
      final track = XTrack.none();
      expect(track.isNone, isTrue);
      expect(track.id, 'no');
      expect(track.type, XTrackType.subtitle);
    });

    test('普通轨道不是 none', () {
      const track = XTrack(
        id: 'aid-1',
        type: XTrackType.audio,
        title: '普通话',
        language: 'chi',
      );
      expect(track.isNone, isFalse);
      expect(track.displayTitle, '普通话');
    });

    test('displayTitle 对 und 语言显示未知', () {
      const track = XTrack(
        id: 'sid-2',
        type: XTrackType.subtitle,
        title: 'und',
      );
      expect(track.displayTitle, '未知');
    });

    test('displayTitle 对空标题返回空字符串', () {
      const track = XTrack(id: 'vid-1', type: XTrackType.video);
      expect(track.displayTitle, '');
    });

    test('相等性基于 id', () {
      const a = XTrack(id: 'aid-1', type: XTrackType.audio, title: 'A');
      const b = XTrack(id: 'aid-1', type: XTrackType.audio, title: 'B');
      const c = XTrack(id: 'aid-2', type: XTrackType.audio, title: 'A');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('XTrackSelection', () {
    test('默认所有轨道为空', () {
      const selection = XTrackSelection();
      expect(selection.audio, isNull);
      expect(selection.video, isNull);
      expect(selection.subtitle, isNull);
    });
  });
}
