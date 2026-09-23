import 'package:get/get.dart';

import 'package:xlist/storages/index.dart';

class SettingDocumentController extends GetxController {
  // 用户自定义的文档支持类型
  final documentSupportTypes =
      Get.find<PreferencesStorage>().documentSupportTypes.val.obs;

  /// 切换文档支持类型
  /// [type] 文档类型
  void toggleDocumentSupportType(String type) {
    final types = documentSupportTypes; // RxList：add/remove 自带 refresh，无需手动通知
    types.contains(type) ? types.remove(type) : types.add(type);

    // 更新偏好设置
    Get.find<PreferencesStorage>().documentSupportTypes.val = types.toList();
  }
}
