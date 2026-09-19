import 'package:get/get.dart';
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
    } catch (e) {}
    return this;
  }
}
