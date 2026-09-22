import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/common/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/services/audio_player_service.dart';

/// 当前路由（由 GetMaterialApp.routingCallback 更新）。
/// mini 播放条靠它判断「是否已经在全屏播放页」。
final RxString currentRoute = ''.obs;

/// 迷你播放条覆盖层，挂在 GetMaterialApp.builder 的 Stack 里。
///
/// 两个约束（踩过的坑，改这里务必保留）：
///  1. 本组件必须返回 [Positioned] —— `Stack` 的非定位子节点拿的是**松约束**，
///     直接给 Align/SafeArea 会让播放条按自身大小居中，表现为「悬浮在屏幕中间」。
///  2. main.dart 里 app 子树也要用 `Positioned.fill`，否则页面本身也会塌缩，
///     表现为「不满屏 + 背景发黑」。
class MiniPlayerOverlay extends StatelessWidget {
  const MiniPlayerOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 全屏播放页自己就是播放界面，不再叠一条
      if (currentRoute.value.startsWith(Routes.AUDIO_PLAYER)) {
        return const SizedBox.shrink();
      }

      // 左右拉满、钉死底部。未播放时内容自身是零高度，不会挡住下面的操作
      return const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: MiniAudioPlayerBar(),
      );
    });
  }
}

/// 底部迷你播放条
///
/// 播放服务（全局常驻）一旦装载了播放源就出现；点它回到全屏播放页
/// （复用正在播放的源，不会重头播）。
class MiniAudioPlayerBar extends StatelessWidget {
  const MiniAudioPlayerBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = AudioPlayerService.to;

    return Obx(() {
      // 没在播放时不占位
      if (!service.isActive.value || service.currentName.value.isEmpty) {
        return const SizedBox.shrink();
      }

      return SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => _openFullPlayer(service),
          child: Container(
            margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: Get.isDarkMode
                  ? const Color.fromARGB(255, 28, 28, 30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Row(
              children: [
                // 封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 80.w,
                    height: 80.w,
                    child: CachedNetworkImage(
                      imageUrl: service.object.value.thumb ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CupertinoActivityIndicator(radius: 8.0),
                      errorWidget: (context, url, error) =>
                          Icon(CupertinoIcons.music_note, size: 40.w),
                    ),
                  ),
                ),
                SizedBox(width: 20.w),

                // 文件名 + 进度
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CommonUtils.formatFileNme(service.currentName.value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Get.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8.h),
                      Obx(
                        () => Text(
                          '${PlayerHelper.formatDuration(service.currentPos.value)}'
                          ' / '
                          '${PlayerHelper.formatDuration(service.duration.value)}',
                          style: Get.textTheme.bodySmall?.copyWith(
                            color: Get.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 播放/暂停
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Obx(
                    () => Icon(
                      service.isPlaying.value
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      size: CommonUtils.isPad ? 26 : 60.sp,
                    ),
                  ),
                  onPressed: service.togglePlay,
                ),

                // 关闭（停止并收起）
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: CommonUtils.isPad ? 22 : 48.sp,
                    color: Get.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                  onPressed: service.stopAndRelease,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// 回到全屏播放页；正在播的就是当前文件，服务会复用不重新 open
  void _openFullPlayer(AudioPlayerService service) {
    if (Get.currentRoute.startsWith(Routes.AUDIO_PLAYER)) return;

    Get.toNamed(
      Routes.AUDIO_PLAYER,
      arguments: {
        'path': service.path.value,
        'name': service.currentName.value,
      },
    );
  }
}
