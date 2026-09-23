import 'package:get/get.dart';

import 'package:xlist/storages/index.dart';

class SettingAudioController extends GetxController {
  // 用户自定义的音频支持类型
  final audioSupportTypes =
      Get.find<PreferencesStorage>().audioSupportTypes.val.obs;

  /// 切换音频支持类型
  /// [type] 音频类型
  void toggleAudioSupportType(String type) {
    final types = audioSupportTypes; // RxList：add/remove 自带 refresh，无需手动通知
    types.contains(type) ? types.remove(type) : types.add(type);

    // 更新偏好设置
    Get.find<PreferencesStorage>().audioSupportTypes.val = types.toList();
  }
}
