import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

// DeviceInfo
class DeviceInfoService extends GetxService {
  static DeviceInfoService get to => Get.find();

  // androidInfo
  late AndroidDeviceInfo _androidInfo;
  AndroidDeviceInfo get androidInfo => _androidInfo;

  // Init
  Future<DeviceInfoService> init() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (GetPlatform.isAndroid) _androidInfo = await deviceInfo.androidInfo;
    } catch (e) {
      debugPrint('XLIST_DEVICE 获取设备信息失败: $e');
    }
    return this;
  }
}
