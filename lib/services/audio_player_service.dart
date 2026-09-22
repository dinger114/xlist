import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/widgets.dart';
import 'package:audio_service/audio_service.dart' hide QueueState;
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/core/player/media_kit_player.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/database/entity/index.dart';
import 'package:xlist/services/database_service.dart';
import 'package:xlist/services/download_service.dart';
import 'package:xlist/services/player_notification_service.dart';

/// 播完之后的动作
class CompletedAction {
  /// 下一首的下标；[replayInPlace] 为 true 时无意义
  final int? nextIndex;

  /// 原地重播当前这首（单曲循环 / 单曲队列）
  final bool replayInPlace;

  const CompletedAction._(this.nextIndex, this.replayInPlace);

  /// 原地重播
  static const replay = CompletedAction._(null, true);

  /// 什么都不做（播完暂停等）
  static const stop = CompletedAction._(null, false);

  /// 切到指定下标
  static CompletedAction switchTo(int index) => CompletedAction._(index, false);
}

/// 一首播完后该做什么。纯函数，便于单测（播放模式是最易错的分支）。
///
/// 注意「原地重播」与「什么都不做」是两种不同结果：前者要继续播，后者要停住
/// （播完暂停）。早期实现把两者都当成 null 处理，会让「播完暂停」变成循环播放。
CompletedAction nextActionOnCompleted({
  required int currentIndex,
  required int queueLength,
  required int playMode,
  int Function(int queueLength)? randomPicker,
}) {
  // 队列只有一首：无论什么模式都原地重播（避免无限切歌）
  if (queueLength <= 1) return CompletedAction.replay;

  switch (playMode) {
    case PlayMode.SINGLE_LOOP:
      return CompletedAction.replay;
    case PlayMode.LIST_LOOP:
      return CompletedAction.switchTo(
          currentIndex >= queueLength - 1 ? 0 : currentIndex + 1);
    case PlayMode.SHUFFLE:
      return CompletedAction.switchTo(
          (randomPicker ?? _defaultRandomPick)(queueLength));
    default:
      // PLAY_PAUSE 等：播完即停
      return CompletedAction.stop;
  }
}

/// 兼容旧签名：返回要切换的下标，null 表示不切歌（原地重播或停止都有可能）。
/// 新代码请直接用 [nextActionOnCompleted]。
int? nextIndexOnCompleted({
  required int currentIndex,
  required int queueLength,
  required int playMode,
  int Function(int queueLength)? randomPicker,
}) {
  return nextActionOnCompleted(
    currentIndex: currentIndex,
    queueLength: queueLength,
    playMode: playMode,
    randomPicker: randomPicker,
  ).nextIndex;
}

int _defaultRandomPick(int queueLength) =>
    CommonUtils.randomInt(0, queueLength - 1).toInt();

/// 音频播放服务（全局常驻）
///
/// 播放器原先挂在 `AudioPlayerController` 上，而该 controller 是路由级实例：
/// 页面 pop 后 GetX 的 SmartManagement.full 会 delete 它并触发 `onClose()`，
/// 里面 `player.dispose()` 直接把播放器销毁 —— 这就是「返回即停止播放」的根因。
/// 同时通知栏的 _play/_pause 闭包与 streamController 也一并失效，返回后
/// 通知栏 / 锁屏控制同样失灵。
///
/// 把播放器搬进 GetxService（`Get.putAsync` 注册，不随路由回收）后：
///   - 返回上一页、切到别的页面，播放继续；
///   - 通知栏、锁屏控制持续可用；
///   - 播放页退化成纯视图，mini 播放条与全屏页共享同一份状态。
class AudioPlayerService extends GetxService with WidgetsBindingObserver {
  static AudioPlayerService get to => Get.find();

  // ============ 播放源信息 ============
  final object = ObjectModel().obs; // 当前文件信息
  final objects = <ObjectModel>[].obs; // 播放队列
  final currentName = ''.obs; // 当前文件名
  final currentIndex = 0.obs; // 当前下标
  final path = ''.obs; // 所在目录
  final userInfo = UserModel().obs; // 用户信息
  final httpHeaders = <String, String>{}.obs; // 请求头

  // ============ 播放状态 ============
  final isPlaying = false.obs;
  final isLoading = true.obs;
  final duration = Duration.zero.obs;
  final currentPos = Duration.zero.obs;
  final bufferPos = Duration.zero.obs;
  final playMode = 0.obs;

  /// 是否已装载播放源（决定 mini 播放条是否显示）
  final isActive = false.obs;

  // 定时关闭（常驻 service，离开播放页也继续计时）
  final timerDuration = Duration.zero.obs;
  Timer? _timer;

  // 下载页进入时使用
  String _file = '';
  int _downloadId = 0;

  MediaKitPlayer? _player;
  MediaKitPlayer get player => _player!;

  final audioHandler = PlayerNotificationService.to.audioHandler;

  final List<StreamSubscription> _subscriptions = [];
  Timer? _timerProgress;
  int _progressId = 0;
  MediaItem? _mediaItem;
  String _sourceUrl = '';

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
  }

  /// 后台播放开关（设置页可改）。关闭时 App 退到后台即暂停。
  /// 注：这个开关原先只作用于视频页，音频页从未读过它。
  bool get isBackgroundPlay =>
      Get.find<PreferencesStorage>().isBackgroundPlay.val;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (isActive.value && isPlaying.value && !isBackgroundPlay) {
        pause();
      }
    }
  }

  /// 初始化（GetxService 约定：注册时调用）
  Future<AudioPlayerService> init() async => this;

  /// 当前播放源是否与请求一致（避免重复进入播放页时从头播放）
  bool isSameSource({required String path, required String name}) {
    return isActive.value &&
        this.path.value == path &&
        currentName.value == name;
  }

  // ============ 打开播放源 ============

  /// 装载播放队列并开始播放。
  ///
  /// [objects] 同目录的候选文件（内部会再过滤一次音频）；
  /// [file] / [downloadId] 为下载页播放本地文件时使用。
  Future<void> open({
    required String path,
    required String name,
    List<ObjectModel> objects = const [],
    String file = '',
    int downloadId = 0,
    int? serverId,
  }) async {
    // 同一个源：不重新 open，只保留现有播放进度
    if (isSameSource(path: path, name: name) && _player != null) return;

    this.path.value = path;
    _file = file;
    _downloadId = downloadId;
    if (serverId != null) {
      Get.find<UserStorage>().serverId.val = serverId;
    }

    // 过滤非音频
    this.objects.value =
        objects.where((o) => PreviewHelper.isAudio(o.name!)).toList();

    isLoading.value = true;
    isActive.value = true;

    currentName.value = name;
    currentIndex.value = this.objects.indexWhere((o) => o.name == name);

    userInfo.value = await UserRepository.me();

    _ensurePlayer();

    // 获取文件信息
    if (_file.isEmpty) {
      try {
        object.value = await ObjectRepository.get(path: '${path}${name}');
        httpHeaders.value = await DriverHelper.getHeaders(
            object.value.provider, object.value.rawUrl);
      } catch (e) {
        SmartDialog.showToast(e.toString());
        isLoading.value = false;
        return;
      }
    } else {
      final download = await DatabaseService.to.database.downloadDao
          .findDownloadById(_downloadId);
      object.value = ObjectModel.fromJson({
        'name': download?.name,
        'type': download?.type,
        'size': download?.size,
        'raw_url': 'file://${_file}',
      });
    }

    // 更新播放进度（同时启动每 5 秒落库的定时器）
    await updateProgress();

    // 立即设置 MediaItem，保证标题第一时间上通知
    _playerNotificationHandler();

    // 初始化播放器
    _sourceUrl = object.value.rawUrl ?? '';
    await PlayerHelper.setOption(player,
        isAudioOnly: true, headers: httpHeaders);
    await player.open(_sourceUrl, headers: httpHeaders, autoPlay: true);
    if (currentPos.value.inMilliseconds > 0) {
      await player.seek(currentPos.value);
    }

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, name);

    isLoading.value = false;
  }

  /// 懒创建播放器（App 启动时不常驻 mpv 实例），并挂上事件监听
  void _ensurePlayer() {
    if (_player != null) return;

    final p = MediaKitPlayer();
    _player = p;

    audioHandler.setQueueMode(
      isPlaylist: objects.length > 1,
      isVideo: false,
    );
    audioHandler.initializeStreamController(p, objects.length > 1, false);
    audioHandler.playbackState.addStream(audioHandler.streamController.stream);
    audioHandler.setVideoFunctions(
      p.play,
      p.pause,
      (ms) => p.seek(Duration(milliseconds: ms)),
      p.stop,
    );

    _attachPlayerListeners(p);
  }

  /// 挂载播放器事件监听
  void _attachPlayerListeners(MediaKitPlayer p) {
    _subscriptions.add(p.playingStream.listen((playing) {
      isPlaying.value = playing;
      Future.delayed(Duration(milliseconds: 1000), () {
        audioHandler.updatePlaybackState();
      });
    }));

    _subscriptions.add(p.durationStream.listen((dur) {
      if (dur != duration.value) {
        duration.value = dur;
      }
    }));

    _subscriptions.add(p.positionStream.listen((pos) {
      currentPos.value = pos;
    }));

    _subscriptions.add(p.bufferStream.listen((buf) {
      bufferPos.value = buf;
    }));

    _subscriptions.add(p.stateStream.listen((state) {
      if (state == XPlayerState.ready || state == XPlayerState.playing) {
        _playerNotificationHandler();
      }

      if (state == XPlayerState.completed) {
        _onCompleted();
      }
    }));

    _subscriptions.add(p.errorStream.listen((err) {
      SmartDialog.showToast('toast_play_error'.tr);
    }));
  }

  /// 播放完成：按播放模式决定下一首
  void _onCompleted() {
    currentPos.value = Duration.zero;

    // 更新播放进度 - 重置
    DatabaseService.to.database.progressDao.updateProgress(
      ProgressEntity(
        id: _progressId,
        serverId: Get.find<UserStorage>().serverId.val,
        path: path.value,
        name: currentName.value,
        currentPos: 0,
      ),
    );

    final action = nextActionOnCompleted(
      currentIndex: currentIndex.value,
      queueLength: objects.length,
      playMode: playMode.value,
    );

    if (action.replayInPlace) {
      // 单曲循环 / 单曲队列：原地重播，继续播
      player.seek(Duration.zero);
      player.play();
      return;
    }

    // 播完暂停等：停住，不切歌
    if (action.nextIndex == null) return;

    // 随机模式可能抽到当前这首，用 allowSameIndex 放行，否则会被
    // 「已是当前播放文件」挡掉，导致播完卡住
    changePlaylist(action.nextIndex!, allowSameIndex: true);
  }

  /// 通知栏控制器
  void _playerNotificationHandler() {
    _mediaItem = MediaItem(
      id: '${path.value}${currentName.value}',
      title: CommonUtils.formatFileNme(currentName.value),
      duration: duration.value,
      artUri: object.value.thumb != null && object.value.thumb!.isNotEmpty
          ? Uri.parse(object.value.thumb!)
          : Uri.parse('https://s2.loli.net/2023/07/05/viCwFoLceMtAB3m.jpg'),
      artHeaders: httpHeaders,
    );

    audioHandler.mediaItem.add(_mediaItem);
  }

  /// 切换播放列表文件
  /// [index] 下标
  /// [allowSameIndex] 播完自动切歌时，随机模式可能抽到当前这首
  void changePlaylist(int index, {bool allowSameIndex = false}) async {
    if (index < 0 || index >= objects.length) return;

    final _object = objects[index];
    if (index == currentIndex.value && !allowSameIndex) {
      SmartDialog.showToast('toast_current_play_file'.tr);
      return;
    }

    // 获取文件信息
    SmartDialog.showLoading();
    try {
      object.value =
          await ObjectRepository.get(path: '${path.value}${_object.name}');
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
      return;
    }

    currentIndex.value = index;
    currentName.value = _object.name!;

    // 重置播放器信息
    SmartDialog.dismiss();
    currentPos.value = Duration.zero;
    await updateProgress(); // 更新播放进度

    // 初始化播放器
    _sourceUrl = object.value.rawUrl ?? '';
    await PlayerHelper.setOption(player,
        isAudioOnly: true, headers: httpHeaders);
    await player.open(_sourceUrl, headers: httpHeaders, autoPlay: true);
    if (currentPos.value.inMilliseconds > 0) {
      await player.seek(currentPos.value);
    }

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path.value, _object.name!);
  }

  /// 播放/暂停切换（乐观更新 UI，由 playingStream 校正）
  void togglePlay() {
    if (isPlaying.value) {
      isPlaying.value = false;
      player.pause();
    } else {
      isPlaying.value = true;
      player.play();
    }
  }

  void play() => _player?.play();
  void pause() => _player?.pause();
  void seek(Duration position) => _player?.seek(position);
  void stop() => _player?.stop();

  /// 重试播放
  void retryPlay() async {
    if (_sourceUrl.isEmpty) return;
    try {
      await player.open(_sourceUrl, headers: httpHeaders, autoPlay: true);
      if (currentPos.value.inMilliseconds > 0) {
        await player.seek(currentPos.value);
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 切换播放速度
  void setSpeed(double value) {
    _player?.setRate(value);
  }

  /// 切换播放模式（列表循环 → 单集循环 → 播完暂停 → 随机）
  void nextPlayMode() {
    playMode.value = playMode.value == PlayMode.SHUFFLE
        ? PlayMode.LIST_LOOP
        : playMode.value + 1;
  }

  /// 定时关闭
  Future<void> timedShutdown() async {
    final _hasTimer = timerDuration.value.inSeconds > 0;
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      title:
          '定时关闭${_hasTimer ? '(剩余${timerDuration.value.inMinutes + 1}分钟)' : ''}',
      actions: [
        SheetAction(label: '5分钟', key: 5),
        SheetAction(label: '10分钟', key: 10),
        SheetAction(label: '15分钟', key: 15),
        SheetAction(label: '30分钟', key: 30),
        SheetAction(label: '60分钟', key: 60),
        ...[
          if (_hasTimer)
            SheetAction(label: '关闭定时', key: 0, isDestructiveAction: true)
        ].whereType<SheetAction>().toList(),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return;

    // 关闭定时
    if (value == 0) {
      _timer?.cancel();
      timerDuration.value = Duration.zero;
      SmartDialog.showToast('关闭定时');
      return;
    }

    _timer?.cancel();
    timerDuration.value = Duration(minutes: value);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      timerDuration.value = timerDuration.value - Duration(seconds: 1);
      if (timerDuration.value.inSeconds == 0) {
        _timer?.cancel();
        pause();
      }
    });

    SmartDialog.showToast('${value}分钟后关闭');
  }

  /// 更新本地播放进度（含每 5 秒落库的定时器）
  Future<void> updateProgress() async {
    final serverId = Get.find<UserStorage>().serverId.val;
    final progress = await DatabaseService.to.database.progressDao
        .findProgressByServerIdAndPath(serverId, path.value, currentName.value);

    if (progress != null) {
      _progressId = progress.id!;
      currentPos.value = Duration(milliseconds: progress.currentPos);
    } else {
      _progressId =
          await DatabaseService.to.database.progressDao.insertProgress(
        ProgressEntity(
          serverId: serverId,
          path: path.value,
          name: currentName.value,
          currentPos: 0,
        ),
      );
    }

    // 每五秒记录一下播放进度
    _timerProgress?.cancel();
    _timerProgress = Timer.periodic(Duration(seconds: 5), (timer) async {
      await DatabaseService.to.database.progressDao.updateProgress(
        ProgressEntity(
          id: _progressId,
          serverId: Get.find<UserStorage>().serverId.val,
          path: path.value,
          name: currentName.value,
          currentPos: currentPos.value.inMilliseconds,
        ),
      );
    });
  }

  /// 停止播放并卸载 UI 状态（mini 播放条的关闭按钮）。
  /// 播放器实例保留，下次播放复用（dispose 由 onClose / App 退出负责）。
  void stopAndRelease() {
    _timer?.cancel();
    _timerProgress?.cancel();
    timerDuration.value = Duration.zero;

    _player?.stop();
    audioHandler.resetPlaybackState();

    isActive.value = false;
    isPlaying.value = false;
    isLoading.value = true;
    currentPos.value = Duration.zero;
    duration.value = Duration.zero;
    bufferPos.value = Duration.zero;
    _sourceUrl = '';
  }

  @override
  void onClose() {
    super.onClose();

    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timerProgress?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // 先释放播放器，再关 streamController（stopStream 内部会 close）
    _player?.dispose();
    _player = null;
    audioHandler.releaseStreamController();

    DownloadService.to.unbindBackgroundIsolate();
  }
}
