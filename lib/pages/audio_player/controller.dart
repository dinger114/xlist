import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/helper/player_helper.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/media_kit_player.dart';
import 'package:xlist/database/entity/index.dart';

class AudioPlayerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final isPlaylist = false.obs; // 是否显示为播放列表
  final object = ObjectModel().obs; // 文件信息
  final isLoading = true.obs; // 是否正在加载
  final playMode = 0.obs; // 播放模式
  final httpHeaders = Map<String, String>().obs;
  final serverId = Get.find<UserStorage>().serverId.val.obs;
  final userInfo = UserModel().obs; // 用户信息

  // 获取参数
  String path = Get.arguments['path'] ?? '';
  String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  // 下载页面点击
  final String file = Get.arguments['file'] ?? '';
  final int downloadId = Get.arguments['downloadId'] ?? 0;

  // 当前播放音频
  final currentName = ''.obs;
  final currentIndex = 0.obs;
  late final MediaKitPlayer player;
  final audioHandler = PlayerNotificationService.to.audioHandler;
  late TabController tabController;

  double seekPos = -1.0.obs;
  final isPlaying = false.obs;
  final duration = Duration().obs;
  final currentPos = Duration().obs;
  final bufferPos = Duration().obs;

  Timer? _timer;
  Timer? _timerProgress;
  int _progressId = 0; // 进度表 ID
  final timerDuration = Duration.zero.obs;
  final List<StreamSubscription> _subscriptions = [];
  MediaItem? _mediaItem;

  // 播放地址（重试用）
  String _sourceUrl = '';

  @override
  void onInit() async {
    super.onInit();

    // TabController
    tabController = TabController(vsync: this, length: 2, initialIndex: 0);
    tabController.addListener(() {
      isPlaylist.value = tabController.index == 1;
    });

    // 过滤非音频
    objects = objects.where((o) => PreviewHelper.isAudio(o.name!)).toList();
    userInfo.value = await UserRepository.me(); // 获取用户信息

    // 当前播放文件名
    currentName.value = name;
    currentIndex.value = objects.indexWhere((o) => o.name == name); // 当前播放文件下标

    // 创建播放器
    player = MediaKitPlayer();

    // PlayerNotificationService
    audioHandler.initializeStreamController(player, objects.length > 1, false);
    audioHandler.playbackState.addStream(audioHandler.streamController.stream);
    audioHandler.setVideoFunctions(
      player.play,
      player.pause,
      (ms) => player.seek(Duration(milliseconds: ms)),
      player.stop,
    );

    // 获取文件信息
    if (file.isEmpty) {
      try {
        object.value = await ObjectRepository.get(path: '${path}${name}');
        httpHeaders.value = await DriverHelper.getHeaders(
            object.value.provider, object.value.rawUrl);
      } catch (e) {
        SmartDialog.showToast(e.toString());
        return;
      }
    } else {
      final download = await DatabaseService.to.database.downloadDao
          .findDownloadById(downloadId);
      object.value = ObjectModel.fromJson({
        'name': download?.name,
        'type': download?.type,
        'size': download?.size,
        'raw_url': 'file://${file}',
      });
    }

    // 更新播放进度
    await updateProgress();

    // 初始化播放器
    _sourceUrl = object.value.rawUrl ?? '';
    await PlayerHelper.setOption(player,
        isAudioOnly: true, headers: httpHeaders);
    await player.open(_sourceUrl, headers: httpHeaders, autoPlay: true);
    if (currentPos.value.inMilliseconds > 0) {
      await player.seek(currentPos.value);
    }

    // 监听播放器状态
    _initStreamListeners();

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, name);

    // 绑定进度监听
    DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
    isLoading.value = false;
  }

  void _initStreamListeners() {
    _subscriptions.add(player.playingStream.listen((playing) {
      isPlaying.value = playing;
      Future.delayed(Duration(milliseconds: 1000), () {
        audioHandler.updatePlaybackState();
      });
    }));

    _subscriptions.add(player.durationStream.listen((dur) {
      if (dur != duration.value) {
        duration.value = dur;
      }
    }));

    _subscriptions.add(player.positionStream.listen((pos) {
      currentPos.value = pos;
    }));

    _subscriptions.add(player.bufferStream.listen((buf) {
      bufferPos.value = buf;
    }));

    _subscriptions.add(player.stateStream.listen((state) {
      if (state == XPlayerState.ready) {
        if (duration.value.inMilliseconds > 0) _playerNotificationHandler();
      }

      if (state == XPlayerState.completed) {
        _onCompleted();
      }
    }));

    _subscriptions.add(player.errorStream.listen((err) {
      SmartDialog.showToast('toast_play_error'.tr);
    }));
  }

  /// 播放完成
  void _onCompleted() {
    currentPos.value = Duration.zero;

    // 更新播放进度 - 重置
    DatabaseService.to.database.progressDao.updateProgress(
      ProgressEntity(
        id: _progressId,
        serverId: serverId.value,
        path: path,
        name: currentName.value,
        currentPos: currentPos.value.inMilliseconds,
      ),
    );

    // 根据播放模式切换下一首
    switch (playMode.value) {
      case PlayMode.SINGLE_LOOP:
        player.seek(Duration.zero);
        player.play();
        break;
      case PlayMode.LIST_LOOP:
        if (objects.length == 1) {
          player.seek(Duration.zero);
          player.play();
        } else {
          currentIndex.value == objects.length - 1
              ? changePlaylist(0)
              : changePlaylist(currentIndex.value + 1);
        }
        break;
      case PlayMode.SHUFFLE:
        if (objects.length == 1) {
          player.seek(Duration.zero);
          player.play();
        } else {
          changePlaylist(CommonUtils.randomInt(0, objects.length - 1));
        }
        break;
      default:
        break;
    }
  }

  /// 通知栏控制器
  void _playerNotificationHandler() {
    _mediaItem = MediaItem(
      id: '${path}${currentName.value}',
      title: CommonUtils.formatFileNme(currentName.value),
      duration: duration.value,
      artUri: object.value.thumb != null && object.value.thumb!.isNotEmpty
          ? Uri.parse(object.value.thumb!)
          : Uri.parse('https://s2.loli.net/2023/07/05/viCwFoLceMtAB3m.jpg'),
      artHeaders: httpHeaders,
    );

    // Add media
    audioHandler.mediaItem.add(_mediaItem);
  }

  /// 切换播放列表文件
  /// [index] 下标
  void changePlaylist(int index) async {
    final _object = objects[index];
    if (index == currentIndex.value) {
      SmartDialog.showToast('toast_current_play_file'.tr);
      return;
    }

    // 获取文件信息
    SmartDialog.showLoading();
    try {
      object.value = await ObjectRepository.get(path: '${path}${_object.name}');
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
    await CommonUtils.addRecent(object.value, path, _object.name!);
  }

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

  /// 定时关闭
  void timedShutdown() async {
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
        Get.find<AudioPlayerController>().player.pause();
      }
    });

    SmartDialog.showToast('${value}分钟后关闭');
  }

  /// 切换播放速度
  void changeSpeed() async {
    final value = await showModalActionSheet(
      context: Get.overlayContext!,
      title: 'play_speed'.tr,
      materialConfiguration: MaterialModalActionSheetConfiguration(),
      actions: [
        SheetAction(label: '2.0X', key: 2.0),
        SheetAction(label: '1.8X', key: 1.8),
        SheetAction(label: '1.5X', key: 1.5),
        SheetAction(label: '1.2X', key: 1.2),
        SheetAction(label: '1.0X', key: 1.0),
        SheetAction(label: '0.5X', key: 0.5),
        SheetAction(label: '恢复默认', key: 1.0),
      ],
      cancelLabel: 'cancel'.tr,
    );
    if (value == null) return;
    player.setRate(value);
    SmartDialog.showToast('toast_switch_success'.tr);
  }

  /// 更新本地播放进度
  Future<void> updateProgress() async {
    final progress = await DatabaseService.to.database.progressDao
        .findProgressByServerIdAndPath(serverId.value, path, currentName.value);

    if (progress != null) {
      _progressId = progress.id!;
      currentPos.value = Duration(milliseconds: progress.currentPos);
    } else {
      _progressId =
          await DatabaseService.to.database.progressDao.insertProgress(
        ProgressEntity(
          serverId: serverId.value,
          path: path,
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
          serverId: serverId.value,
          path: path,
          name: currentName.value,
          currentPos: currentPos.value.inMilliseconds,
        ),
      );
    });
  }

  /// 收藏
  void favorite() async {
    await CommonUtils.addFavorite(object.value, path, currentName.value);
  }

  /// 复制链接
  void copyLink() {
    Clipboard.setData(ClipboardData(
      text: CommonUtils.getDownloadLink(
        path,
        object: object.value,
        userInfo: userInfo.value,
      ),
    ));
    SmartDialog.showToast('toast_copy_success'.tr);
  }

  /// 下载文件
  void download() async {
    DownloadHelper.file(
        path, currentName.value, object.value.type!, object.value.size!);
  }

  @override
  void onClose() {
    super.onClose();

    _timer?.cancel();
    _timerProgress?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    audioHandler.streamController.add(PlaybackState());
    audioHandler.streamController.close();
    player.dispose();

    DownloadService.to.unbindBackgroundIsolate();
  }
}
