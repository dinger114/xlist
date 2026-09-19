import 'dart:io';

import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// 运行时权限申请（启动时调用）
class AppPermissionHelper {
  /// 申请通知权限（Android 13+ 需要 POST_NOTIFICATIONS）
  static Future<void> requestNotification() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      // 老设备无此权限概念，忽略
    }
  }
}
