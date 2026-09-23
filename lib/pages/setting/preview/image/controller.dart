import 'package:get/get.dart';

import 'package:xlist/storages/index.dart';

class SettingImageController extends GetxController {
  // 用户自定义的图片支持类型
  final imageSupportTypes =
      Get.find<PreferencesStorage>().imageSupportTypes.val.obs;

  /// 切换图片支持类型
  /// [type] 图片类型
  void toggleImageSupportType(String type) {
    final types = imageSupportTypes; // RxList：add/remove 自带 refresh，无需手动通知
    types.contains(type) ? types.remove(type) : types.add(type);

    // 更新偏好设置
    Get.find<PreferencesStorage>().imageSupportTypes.val = types.toList();
  }
}
