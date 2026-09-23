import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:xlist/storages/index.dart';

/// 让 `GetStorage` 在单元测试里真正可用。
///
/// 背景：`GetStorage` 初始化时会通过 `path_provider` 找应用文档目录。单元测试
/// 环境没有该插件实现，会抛
/// `MissingPluginException(No implementation found for method
/// getApplicationDocumentsDirectory on channel plugins.flutter.io/path_provider)`。
/// 这个异常是**异步**抛出的，表现很迷惑：有时测试直接失败，有时只在读默认值时
/// 静默走内存缓存、写操作却不落盘。
///
/// 做法：把 path_provider 的 method channel 打桩到一个临时目录，然后用真的
/// `GetStorage.init` 初始化。这样读写都走真实逻辑（而非内存假象），
/// 测试里对 `PreferencesStorage` 的改动才是可信的。
///
/// 用法：
/// ```dart
/// void main() {
///   setUpAll(setUpTestStorage);
///   tearDownAll(tearDownTestStorage);
///   setUp(() { Get.reset(); Get.put<PreferencesStorage>(PreferencesStorage()); });
///   tearDown(Get.reset);
///   ...
/// }
/// ```
Directory? _tempDir;

/// 打桩 path_provider 并初始化 GetStorage。放在 `setUpAll` 里调用。
Future<void> setUpTestStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 临时目录走 TMPDIR（由运行时指向 scratch 目录），收尾时删除
  final dir = Directory.systemTemp.createTempSync('xlist_test_storage_');
  _tempDir = dir;

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        // 无论调用哪个方法（documents / support / temp）都返回同一目录
        return dir.path;
      });

  await GetStorage.init('PreferencesStorage');
}

/// 删除临时目录。放在 `tearDownAll` 里调用。
Future<void> tearDownTestStorage() async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);

  final dir = _tempDir;
  _tempDir = null;
  if (dir != null && dir.existsSync()) {
    dir.deleteSync(recursive: true);
  }
}

/// 注册一份 PreferencesStorage 到 GetX 容器（每次测试都拿干净的容器）。
PreferencesStorage putPreferences() {
  final prefs = PreferencesStorage();
  Get.put<PreferencesStorage>(prefs);
  return prefs;
}
