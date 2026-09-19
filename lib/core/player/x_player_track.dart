/// 轨道类型
enum XTrackType { audio, video, subtitle }

/// 轨道模型（与具体播放库解耦）
class XTrack {
  final String id;
  final XTrackType type;
  final String? title;
  final String? language;

  const XTrack({
    required this.id,
    required this.type,
    this.title,
    this.language,
  });

  /// 空轨道（关闭字幕用）
  factory XTrack.none() => const XTrack(id: 'no', type: XTrackType.subtitle);

  bool get isNone => id == 'no';

  /// 展示标题（兼容原 CommonUtils.formatIjkTrack 语义）
  String get displayTitle {
    final t = title ?? '';
    return t == 'und' ? '未知' : t;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is XTrack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 当前轨道选中状态
class XTrackSelection {
  final XTrack? audio;
  final XTrack? video;
  final XTrack? subtitle;

  const XTrackSelection({this.audio, this.video, this.subtitle});
}
