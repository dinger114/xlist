import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import 'package:xlist/models/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/services/index.dart';

/// 音频播放页 controller —— 现在是纯视图层。
///
/// 播放器、播放队列、播放进度都归 [AudioPlayerService]（全局常驻）。这里只留
/// 页面自己的 UI 状态（tab、拖动中的进度），因此本页面被 pop 时不再销毁播放
/// 器 —— 「返回即停止播放」的根因就在原来的 onClose 里那句 player.dispose()。
///
/// 为了让 view 少改动，[player] 直接指向播放服务：
/// `controller.player.isPlaying` / `controller.togglePlay()` 等照旧可用。
class AudioPlayerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final isPlaylist = false.obs; // 是否显示为播放列表
  final userInfo = UserModel().obs; // 用户信息

  /// 播放服务（全局常驻）
  AudioPlayerService get player => AudioPlayerService.to;

  /// 当前播放文件信息（view 里 controller.object 的别名）
  ObjectModel get object => player.object.value;

  // 获取参数
  String path = Get.arguments['path'] ?? '';
  String name = Get.arguments['name'] ?? '';
  List<ObjectModel> objects = Get.arguments['objects'] ?? [];

  // 下载页面点击
  final String file = Get.arguments['file'] ?? '';
  final int downloadId = Get.arguments['downloadId'] ?? 0;

  late TabController tabController;

  /// 拖动中的进度（-1 表示未拖动）
  /// 先赋 RxDouble 再当 double 用，是为了让 Obx 在拖动时也能收到通知
  /// （与原实现保持一致）
  double seekPos = -1.0.obs;

  @override
  void onInit() async {
    super.onInit();

    // TabController
    tabController = TabController(vsync: this, length: 2, initialIndex: 0);
    tabController.addListener(() {
      isPlaylist.value = tabController.index == 1;
    });

    // 播放模式跟随全局偏好
    player.playMode.value = Get.find<PreferencesStorage>().playMode.val;

    // 装载播放源；若已在播同一个文件则复用（不重新从头播放）
    await player.open(
      path: path,
      name: name,
      objects: objects,
      file: file,
      downloadId: downloadId,
      serverId: Get.arguments['serverId'],
    );

    userInfo.value = await UserRepository.me();
  }

  /// 播放/暂停切换
  void togglePlay() => player.togglePlay();

  /// 切换播放列表文件
  void changePlaylist(int index) => player.changePlaylist(index);

  /// 上一首（随机模式抽一首）
  void previous() {
    if (player.objects.isEmpty) return;
    if (player.playMode.value == PlayMode.shuffle) {
      player.changePlaylist(
          CommonUtils.randomInt(0, player.objects.length - 1).toInt());
      return;
    }
    player.currentIndex.value == 0
        ? player.changePlaylist(player.objects.length - 1)
        : player.changePlaylist(player.currentIndex.value - 1);
  }

  /// 下一首（随机模式抽一首）
  void next() {
    if (player.objects.isEmpty) return;
    if (player.playMode.value == PlayMode.shuffle) {
      player.changePlaylist(
          CommonUtils.randomInt(0, player.objects.length - 1).toInt());
      return;
    }
    player.currentIndex.value == player.objects.length - 1
        ? player.changePlaylist(0)
        : player.changePlaylist(player.currentIndex.value + 1);
  }

  /// 切换播放列表显示
  void togglePlaylist() {
    isPlaylist.value = !isPlaylist.value;
    tabController.index = isPlaylist.value ? 1 : 0;
  }

  /// 切换播放模式
  void changePlayMode() {
    player.nextPlayMode();
    Get.find<PreferencesStorage>().playMode.val = player.playMode.value;
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
    player.setSpeed(value);
    SmartDialog.showToast('toast_switch_success'.tr);
  }

  /// 定时关闭
  void timedShutdown() => player.timedShutdown();

  /// 收藏
  void favorite() async {
    await CommonUtils.addFavorite(
        player.object.value, path, player.currentName.value);
  }

  /// 复制链接
  void copyLink() {
    Clipboard.setData(ClipboardData(
      text: CommonUtils.getDownloadLink(
        path,
        object: player.object.value,
        userInfo: userInfo.value,
      ),
    ));
    SmartDialog.showToast('toast_copy_success'.tr);
  }

  /// 下载文件
  void download() async {
    DownloadHelper.file(path, player.currentName.value,
        player.object.value.type!, player.object.value.size!);
  }

  @override
  void onClose() {
    super.onClose();

    // 只释放页面自己的 UI 资源。播放器由 AudioPlayerService 持有，
    // 这里绝不能 dispose —— 否则返回上一页就停止播放（本次修复的根因）。
    tabController.dispose();
  }
}
