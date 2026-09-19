import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:charset/charset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:audio_service/audio_service.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/common/utils.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/helper/player_helper.dart';
import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/x_player_track.dart';
import 'package:xlist/core/player/media_kit_player.dart';
import 'package:xlist/database/entity/index.dart';

class VideoPlayerController extends SuperController {
  final object = ObjectModel().obs;
  final userInfo = UserModel().obs; // 用户信息
  final httpHeaders = Map<String, String>().obs;
  final serverId = Get.find<UserStorage>().serverId.val.obs;
  final isLoading = true.obs; // 是否正在加载
  final isAutoPaused = false.obs; // 是否自动暂停
  final subtitles = <Subtitle>[].obs; // 字幕
  final subtitleNameList = <String>[].obs; // 字幕文件名列表
  final subtitleName = ''.obs; // 当前字幕文件名
  final audioTracks = <XTrack>[].obs; // 音轨
  final subtitleTracks = <XTrack>[].obs; // 内置字幕轨
  final showTimedText = true.obs; // 是否显示内置字幕
  final currentName = ''.obs; // 当前播放文件名
  final currentIndex = 0.obs; // 当前播放文件下标
  final showPlaylist = false.obs; // 是否显示播放列表
  final thumbnail = ''.obs; // 视频缩略图

  // 当前位置 / 缓冲 / 时长
  final currentPos = Duration.zero.obs;
  final bufferPos = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final isPlaying = false.obs;
  final isBuffering = false.obs;

  // 自动播放
  final isAutoPlay = Get.find<PreferencesStorage>().isAutoPlay.val;

  // 后台播放
  final isBackgroundPlay = Get.find<PreferencesStorage>().isBackgroundPlay.val;

  // 播放模式
  final playMode = Get.find<PreferencesStorage>().playMode;

  // 获取参数
  final String path = Get.arguments['path'] ?? '';
  final String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  // 下载页面点击
  final String file = Get.arguments['file'] ?? '';
  final int downloadId = Get.arguments['downloadId'] ?? 0;

  // 初始化播放器（抽象层）
  late final MediaKitPlayer player;
  late final XVideoController videoController;
  final audioHandler = PlayerNotificationService.to.audioHandler;

  // 播放地址（重试用）
  String _sourceUrl = '';

  StreamSubscription? _currentPosSubs;
  final List<StreamSubscription> _subscriptions = [];
  Timer? _timer;
  int _progressId = 0; // 进度表 ID
  MediaItem? _mediaItem;

  @override
  void onInit() async {
    super.onInit();

    // 过滤掉非视频文件
    objects = objects.where((o) => PreviewHelper.isVideo(o.name!)).toList();
    userInfo.value = await UserRepository.me(); // 获取用户信息

    // 当前播放文件名
    currentName.value = name;
    currentIndex.value = objects.indexWhere((o) => o.name == name); // 当前播放文件下标
    showPlaylist.value = objects.length > 1; // 是否显示播放列表

    // 创建播放器与视频控制器
    player = MediaKitPlayer();
    videoController = XVideoController(player);

    // PlayerNotificationService
    audioHandler.initializeStreamController(player, showPlaylist.value, true);
    audioHandler.playbackState.addStream(audioHandler.streamController.stream);
    audioHandler.setVideoFunctions(
      player.play,
      player.pause,
      (ms) => player.seek(Duration(milliseconds: ms)),
      player.stop,
    );

    // 获取视频播放地址
    if (file.isEmpty) {
      try {
        object.value = await ObjectRepository.get(path: '${path}${name}');
      } catch (e) {
        SmartDialog.showToast('toast_get_object_fail'.tr);
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

      // 尝试更新一下字幕
      ObjectRepository.get(path: '${path}${name}').then((value) {
        updateSubtitleNameList(value.related ?? []);
      });
    }

    // 获取字幕文件名列表
    updateSubtitleNameList(object.value.related ?? []);
    thumbnail.value = object.value.thumb ?? '';

    // 获取服务器 id
    if (Get.arguments['serverId'] != null) {
      serverId.value = Get.arguments['serverId'] ?? 0;
    }

    // 更新播放进度
    await updateProgress();

    // 初始化播放器
    // 先挂监听再 open，否则 ready 事件在监听前已错过，通知栏拿不到 MediaItem
    _initStreamListeners();

    try {
      _sourceUrl = await StrmHelper.resolvePlayUrl(object.value, name);
      httpHeaders.value = StrmHelper.getHeaders(object.value, _sourceUrl);
      await PlayerHelper.setOption(
        player,
        headers: httpHeaders,
        name: name,
      );
      await player.open(
        _sourceUrl,
        headers: httpHeaders,
        autoPlay: isAutoPlay,
      );
      // 续播：open 后立即 seek
      if (currentPos.value.inMilliseconds > 0) {
        await player.seek(currentPos.value);
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
      return;
    }

    // 画中画：视频页允许在离开时自动进入 PiP
    PipHelper.onVideoPageEnter();

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, name);

    // 绑定进度监听
    DownloadService.to.bindBackgroundIsolate((id, status, progress) {});
    isLoading.value = false; // 加载完成
  }

  void _initStreamListeners() {
    _subscriptions.add(player.stateStream.listen((state) {
      switch (state) {
        case XPlayerState.playing:
          WakelockPlus.enable();
          break;
        case XPlayerState.paused:
          WakelockPlus.disable();
          break;
        case XPlayerState.ready:
          _playerNotificationHandler();
          _loadTracks();
          break;
        case XPlayerState.completed:
          _onCompleted();
          break;
        case XPlayerState.error:
          SmartDialog.showToast('toast_play_error'.tr);
          break;
        default:
          break;
      }
    }));

    _subscriptions.add(player.playingStream.listen((playing) {
      isPlaying.value = playing;
    }));

    _subscriptions.add(player.bufferingStream.listen((buffering) {
      isBuffering.value = buffering;
    }));

    _subscriptions.add(player.positionStream.listen((pos) {
      currentPos.value = pos;
    }));

    _subscriptions.add(player.bufferStream.listen((buf) {
      bufferPos.value = buf;
    }));

    _subscriptions.add(player.durationStream.listen((dur) {
      if (dur != duration.value) {
        duration.value = dur;
        if (_mediaItem != null && _mediaItem!.duration != dur) {
          _playerNotificationHandler();
        }
      }
    }));

    _subscriptions.add(player.tracksStream.listen((tracks) {
      audioTracks.value =
          tracks.where((t) => t.type == XTrackType.audio).toList();
      subtitleTracks.value =
          tracks.where((t) => t.type == XTrackType.subtitle).toList();
    }));
  }

  /// 加载音轨/字幕轨
  void _loadTracks() {
    if (player.duration.inMilliseconds > 0) _playerNotificationHandler();
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

    // 列表循环
    if (playMode.val == PlayMode.LIST_LOOP && showPlaylist.isTrue) {
      player.seek(Duration.zero);
      currentIndex.value == objects.length - 1
          ? changePlaylist(0)
          : changePlaylist(currentIndex.value + 1);
      return;
    }

    // 单集循环
    if (playMode.val == PlayMode.SINGLE_LOOP && showPlaylist.isTrue) {
      player.seek(Duration.zero);
      player.play();
      return;
    }
  }

  /// 重试播放（错误状态面板）
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
    if (_object.name == currentName.value) {
      SmartDialog.showToast('toast_current_play_file'.tr);
      return;
    }

    // 获取视频播放地址
    SmartDialog.showLoading();
    try {
      object.value = await ObjectRepository.get(path: '${path}${_object.name}');
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
      return;
    }

    // 更新初始化信息
    currentIndex.value = index;
    currentName.value = _object.name!;
    isAutoPaused.value = false;
    subtitles.clear();
    audioTracks.clear();
    subtitleTracks.clear();

    // 获取字幕文件名列表
    updateSubtitleNameList(object.value.related ?? []);

    // 重置播放器信息
    SmartDialog.dismiss();
    currentPos.value = Duration.zero;
    await updateProgress(); // 更新播放进度

    // 初始化播放器
    try {
      _sourceUrl = await StrmHelper.resolvePlayUrl(
        object.value,
        _object.name!,
      );
      httpHeaders.value = StrmHelper.getHeaders(object.value, _sourceUrl);
      await PlayerHelper.setOption(
        player,
        headers: httpHeaders,
        name: _object.name!,
      );
      await player.open(_sourceUrl, headers: httpHeaders, autoPlay: true);
      if (currentPos.value.inMilliseconds > 0) {
        await player.seek(currentPos.value);
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
      return;
    }

    // 加入最近浏览
    await CommonUtils.addRecent(object.value, path, _object.name!);
    SmartDialog.showToast('toast_switch_success'.tr);
  }

  /// 切换音轨
  void changeAudioTrack({String? value}) async {
    if (value == null) {
      value = await showModalActionSheet(
        context: Get.overlayContext!,
        title: 'video_switch_audio'.tr,
        actions: [
          ...audioTracks.map(
            (t) => SheetAction(
              label: '${t.displayTitle}(${t.language ?? ''})',
              key: t.id,
            ),
          ),
        ],
        cancelLabel: 'cancel'.tr,
      );
    }

    if (value != null) {
      final track = audioTracks.firstWhereOrNull((t) => t.id == value);
      if (track == null) return;

      final current = player.trackSelection.audio;
      if (current?.id == track.id) {
        SmartDialog.showToast('toast_current_audio_track'.tr);
        return;
      }

      await player.pause();
      await Future.delayed(Duration(milliseconds: 500));
      await player.setAudioTrack(track);
      await player.seek(currentPos.value);
      await player.play();
      SmartDialog.showToast('toast_switch_success'.tr);
    }
  }

  /// 更新字幕文件名列表
  void updateSubtitleNameList(List<ObjectModel> related) {
    subtitleNameList.clear();
    related.forEach((v) {
      final ext = p.extension(v.name!).toLowerCase();
      if (ext == '.vtt' || ext == '.srt' || ext == '.ass') {
        subtitleNameList.add(v.name!);
      }
    });
  }

  /// 切换字幕
  void changeSubtitle({String? value}) async {
    if (value == null) {
      value = await showModalActionSheet(
        context: Get.overlayContext!,
        materialConfiguration: MaterialModalActionSheetConfiguration(),
        title: 'video_switch_subtitle'.tr,
        actions: [
          ...subtitleNameList.map(
            (v) => SheetAction(label: v, key: v),
          ),
          ...subtitleTracks.map(
            (t) => SheetAction(
              label: '${t.displayTitle}(${t.language ?? ''})',
              key: 'internal::${t.id}',
            ),
          ),
          SheetAction(
            label: 'player_subtitle_close'.tr,
            key: 'close',
            isDestructiveAction: true,
          ),
        ],
        cancelLabel: 'cancel'.tr,
      );
    }
    if (value == null) return;

    // 关闭字幕
    if (value == 'close') {
      showTimedText.value = false;
      subtitles.value = [];
      subtitles.refresh();
      await player.setSubtitleTrack(null);
      SmartDialog.showToast('toast_subtitle_closed'.tr);
      return;
    }

    // 切换内置字幕
    if (value.startsWith('internal::')) {
      final _value = value.replaceAll('internal::', '');
      final track = subtitleTracks.firstWhereOrNull((t) => t.id == _value);
      if (track == null) return;

      final current = player.trackSelection.subtitle;
      if (current?.id == track.id && showTimedText.value) {
        SmartDialog.showToast('toast_current_subtitle'.tr);
        return;
      }

      await player.pause();
      await Future.delayed(Duration(milliseconds: 500));
      await player.setSubtitleTrack(track);
      await player.seek(currentPos.value);
      await player.play();

      showTimedText.value = true; // 显示字幕
      SmartDialog.showToast('toast_switch_success'.tr);
      return;
    }

    try {
      SmartDialog.showLoading(msg: 'toast_switch_loading'.tr);
      final _object = await ObjectRepository.get(path: '${path}${value}');
      final response = await DioService.to.dio.get(
        _object.rawUrl!,
        options: Options(
          headers: httpHeaders,
          responseDecoder: (List<int> responseBytes, RequestOptions options,
              ResponseBody responseBody) {
            String _data = '';
            try {
              _data = hasUtf32Bom(responseBytes)
                  ? utf32.decode(responseBytes)
                  : (hasUtf16Bom(responseBytes)
                      ? utf16.decode(responseBytes)
                      : utf8.decode(responseBytes));
            } catch (e) {
              _data = gbk.decode(responseBytes);
            }
            return _data;
          },
        ),
      );

      // 获取文件后缀
      final ext = p.extension(value).toLowerCase();

      // ass 单独处理
      if (ext == '.ass') {
        showTimedText.value = false;
        subtitles.value = await CommonUtils.ass2srt(response.data);
        subtitles.refresh();

        SmartDialog.dismiss();
        SmartDialog.showToast('toast_switch_success'.tr);
        return;
      }

      // 字幕类型
      final subtitleType =
          ext == '.vtt' ? SubtitleType.webvtt : SubtitleType.srt;

      // 解析字幕文件
      final data = await SubtitleDataRepository(
        subtitleController: SubtitleController(
          subtitlesContent: response.data,
          subtitleType: subtitleType,
        ),
      ).getSubtitles();

      showTimedText.value = false;
      subtitles.value = data.subtitles;
      subtitles.refresh();

      SmartDialog.dismiss();
      SmartDialog.showToast('toast_switch_success'.tr);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('toast_switch_subtitle_fail'.tr);
    }
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
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
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
  void onPaused() {
    if (player.isPlaying && !isBackgroundPlay) {
      isAutoPaused.value = true;
      player.pause();
    }
  }

  @override
  void onResumed() {
    // 判断大小超过 30g 的大文件
    final isLargeFile = object.value.size! > 30 * 1024 * 1024 * 1024;

    // if player is playing and auto paused
    if (player.isPlaying && isLargeFile) {
      isAutoPaused.value = true;
      player.pause();
    }

    // fix player seek bug
    Future.delayed(Duration(milliseconds: 500), () async {
      if (isLargeFile) await player.seek(currentPos.value);

      if (!player.isPlaying && isAutoPaused.isTrue) {
        isAutoPaused.value = false;
        player.play();
      }
    });
  }

  @override
  void onInactive() {}

  @override
  void onDetached() {}

  @override
  void onHidden() {}

  @override
  void onClose() {
    super.onClose();

    PipHelper.onVideoPageExit();
    _timer?.cancel();
    _currentPosSubs?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    audioHandler.streamController.add(PlaybackState());
    audioHandler.streamController.close();
    player.dispose();

    DownloadService.to.unbindBackgroundIsolate();
    WakelockPlus.disable();
  }
}
