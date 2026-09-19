import 'dart:async';

import 'x_player_state.dart';
import 'x_player_track.dart';

/// 播放器抽象接口：业务层只依赖此接口，不直接依赖 media_kit
abstract class XPlayer {
  // ============ Streams ============
  Stream<XPlayerState> get stateStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferStream;
  Stream<bool> get bufferingStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Stream<String> get errorStream;
  Stream<List<XTrack>> get tracksStream;
  Stream<XTrackSelection> get trackSelectionStream;

  // ============ Snapshots ============
  XPlayerState get state;
  Duration get position;
  Duration get buffer;
  Duration get duration;
  bool get isPlaying;
  bool get isBuffering;
  List<XTrack> get tracks;
  XTrackSelection get trackSelection;

  // ============ Controls ============
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    bool autoPlay = true,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> setRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setAudioTrack(XTrack track);
  Future<void> setSubtitleTrack(XTrack? track);

  // ============ Configuration ============
  Future<void> setHardwareDecode(bool enabled);
  Future<void> setProperty(String key, String value);

  // ============ Lifecycle ============
  Future<void> dispose();
}
