import 'package:get/get.dart';

import 'package:xlist/storages/index.dart';

class SettingVideoController extends GetxController {
  // 用户自定义的视频支持类型
  final videoSupportTypes =
      Get.find<PreferencesStorage>().videoSupportTypes.val.obs;

  /// 切换视频支持类型
  /// [type] 视频类型
  void toggleVideoSupportType(String type) {
    final types = videoSupportTypes; // RxList：add/remove 自带 refresh，无需手动通知
    types.contains(type) ? types.remove(type) : types.add(type);

    // 更新偏好设置
    Get.find<PreferencesStorage>().videoSupportTypes.val = types.toList();
  }
}
