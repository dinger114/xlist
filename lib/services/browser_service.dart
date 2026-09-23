import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserService extends GetxService {
  static BrowserService get to => Get.find();

  late final InAppBrowser _inAppBrowser;

  @override
  void onInit() {
    super.onInit();

    // Init
    _inAppBrowser = DeupInAppBrowser();
  }

  // Open Browser
  void open(String url) {
    _inAppBrowser.openUrlRequest(urlRequest: URLRequest(url: WebUri(url)));
  }
}

class DeupInAppBrowser extends InAppBrowser {
  @override
  Future onBrowserCreated() async {}

  @override
  Future onLoadStart(url) async {}

  @override
  Future onLoadStop(url) async {}

  @override
  void onLoadError(url, code, message) {}

  @override
  void onProgressChanged(progress) {}

  @override
  void onExit() {}
}
