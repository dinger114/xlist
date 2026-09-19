/// 播放器状态（与具体播放库解耦）
enum XPlayerState {
  idle,
  loading,
  ready,
  buffering,
  playing,
  paused,
  completed,
  error,
  stopped,
}
