import 'dart:math';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xlist/gen/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/components/index.dart';
import 'package:xlist/pages/audio_player/index.dart';
import 'package:xlist/services/audio_player_service.dart';

class AudioPlayerPage extends GetView<AudioPlayerController> {
  const AudioPlayerPage({super.key});

  /// 播放服务：播放状态、队列都在这里（controller 只是视图层）
  AudioPlayerService get player => controller.player;

  /// 构建下拉按钮
  Widget _buildPullDownButton() {
    List<PullDownMenuEntry> items = [];

    // 收藏
    items.add(
      PullDownMenuItem(
        title: 'favorite'.tr,
        onTap: () => controller.favorite(),
      ),
    );

    items.addAll([
      PullDownMenuItem(
        title: 'play_speed'.tr,
        onTap: () => controller.changeSpeed(),
      ),
      PullDownMenuItem(
        title: 'pull_down_copy_link'.tr,
        onTap: () => controller.copyLink(),
      ),
      PullDownMenuItem(
        title: 'pull_down_download_file'.tr,
        onTap: () => controller.download(),
      ),
    ]);

    return PullDownButton(
      itemBuilder: (context) => items,
      buttonBuilder: (context, showMenu) => CupertinoButton(
        onPressed: showMenu,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        child: Icon(
          CupertinoIcons.ellipsis_circle,
          size: CommonUtils.navIconSize,
        ),
      ),
    );
  }

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      transitionBetweenRoutes: false,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        child: Icon(
          CupertinoIcons.chevron_down,
          size: CommonUtils.isPad ? 25 : 70.sp,
        ),
        onPressed: () => Get.back(),
      ),
      trailing: _buildPullDownButton(),
    );
  }

  /// 封面图
  Widget _buildCover() {
    return Hero(
      tag: 'cover',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.r),
        child: CachedNetworkImage(
          imageUrl: player.object.value.thumb ?? '',
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              CupertinoActivityIndicator(radius: 13.0),
          errorWidget: (context, url, error) => Assets.common.logo.image(),
        ),
      ),
    );
  }

  /// 构建单个文件
  Widget _buildSingleFile() {
    return Container(
      key: PageStorageKey('single'),
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: CommonUtils.isPad ? 20 : 100.h),
      child: Column(
        children: [
          SizedBox(
            width: CommonUtils.isPad ? 300 : 700.r,
            height: CommonUtils.isPad ? 300 : 700.r,
            child: _buildCover(),
          ),
          SizedBox(height: 50.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 50.w),
            child: Text(
              CommonUtils.formatFileNme(player.currentName.value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 播放列表
  Widget _buildPlaylist() {
    return Container(
      key: PageStorageKey('playlist'),
      padding: EdgeInsets.only(
        top: CommonUtils.isPad ? 20 : 100.h,
        left: 50.w,
        right: 50.w,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: CommonUtils.isPad ? 150 : 300.r,
                height: CommonUtils.isPad ? 150 : 300.r,
                child: _buildCover(),
              ),
              SizedBox(width: 50.w),
              Expanded(
                child: Text(
                  CommonUtils.formatFileNme(player.currentName.value),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 60.h),
          Expanded(
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: player.objects.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => controller.changePlaylist(index),
                  child: SizedBox(
                    height: CommonUtils.isPad ? 50 : 100.h,
                    child: Text(
                      CommonUtils.formatFileNme(player.objects[index].name!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Get.textTheme.titleMedium?.copyWith(
                        color: player.currentIndex.value == index
                            ? Get.theme.primaryColor
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 播放进度
  Widget _buildXSlider() {
    // 计算进度时间
    double duration = player.duration.value.inMilliseconds.toDouble();
    double currentValue = controller.seekPos > 0
        ? controller.seekPos
        : player.currentPos.value.inMilliseconds.toDouble();
    currentValue = min(currentValue, duration);
    currentValue = max(currentValue, 0);

    // 计算缓存进度
    double cacheValue = player.bufferPos.value.inMilliseconds.toDouble();
    cacheValue = min(cacheValue, duration);
    cacheValue = max(cacheValue, 0);

    if (player.duration.value.inMilliseconds == 0) {
      return XSlider(
        colors: XSliderColors(
          cursorColor: Get.theme.primaryColor,
          playedColor: Get.theme.primaryColor,
        ),
        onChangeEnd: (double value) {},
        value: 0,
        onChanged: (double value) {},
      );
    }

    return XSlider(
      colors: XSliderColors(
        cursorColor: Get.theme.primaryColor,
        playedColor: Get.theme.primaryColor,
      ),
      value: currentValue,
      cacheValue: cacheValue,
      min: 0.0,
      max: duration,
      onChanged: (v) {
        controller.seekPos = v;
      },
      onChangeEnd: (v) {
        if (controller.seekPos.toInt() == -1) return;
        player.seek(Duration(milliseconds: v.toInt()));
        player.currentPos.value = Duration(
          milliseconds: controller.seekPos.toInt(),
        );
        controller.seekPos = -1;
      },
    );
  }

  /// 播放时间
  Widget _buildDuration() {
    return SizedBox(
      height: 70.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 500.w,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: 50.w),
            child: Obx(
              () => Text(PlayerHelper.formatDuration(player.currentPos.value)),
            ),
          ),
          Container(
            width: 500.w,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 50.w),
            child: Obx(
              () => Text(PlayerHelper.formatDuration(player.duration.value)),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建播放器控制按钮
  Widget _buildControlButton() {
    return SizedBox(
      height: 120.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CupertinoButton(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.zero,
            onPressed: controller.previous,
            child: Icon(
              CupertinoIcons.backward_end_alt_fill,
              size: CommonUtils.isPad ? 50 : 100.sp,
              color: Get.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          CupertinoButton(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
            onPressed: controller.togglePlay,
            child: Obx(
              () => Icon(
                player.isPlaying.value
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: CommonUtils.isPad ? 65 : 150.sp,
                color: Get.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          CupertinoButton(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.zero,
            onPressed: controller.next,
            child: Icon(
              CupertinoIcons.forward_end_alt_fill,
              size: CommonUtils.isPad ? 50 : 100.sp,
              color: Get.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            SizedBox(
              height: 1150.h,
              child: Obx(
                () => TabBarView(
                  controller: controller.tabController,
                  children: [_buildSingleFile(), _buildPlaylist()],
                ),
              ),
            ),
            SizedBox(height: 50.h),
            Container(
              height: 30.h,
              padding: EdgeInsets.symmetric(horizontal: 50.w),
              child: Obx(() => _buildXSlider()),
            ),
            _buildDuration(),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(),
                  SizedBox(height: 50.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 100.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.centerLeft,
                            onPressed: controller.changePlayMode,
                            child: Icon(
                              PlayMode.getIcon(player.playMode.value),
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color: Get.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.center,
                            child: Icon(
                              CupertinoIcons.list_bullet,
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color: controller.isPlaylist.value
                                  ? Get.theme.primaryColor
                                  : Get.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onPressed: () {
                              controller.isPlaylist.value =
                                  !controller.isPlaylist.value;
                              controller.tabController.index =
                                  controller.isPlaylist.value ? 1 : 0;
                            },
                          ),
                        ),
                        Obx(
                          () => CupertinoButton(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              CupertinoIcons.clock,
                              size: CommonUtils.isPad ? 30 : 70.sp,
                              color: player.timerDuration.value.inSeconds > 0
                                  ? Get.theme.primaryColor
                                  : Get.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onPressed: () => controller.timedShutdown(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
