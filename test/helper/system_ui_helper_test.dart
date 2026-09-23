import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/helper/system_ui_helper.dart';

/// SystemUiHelper 回归测试。
///
/// 真机问题：播放页**左右半屏上下滑动**调音量/亮度完全没反应。
///
/// 根因：fijkplayer 迁移到 media_kit 时（`d635029`），这两项能力随插件一起
/// 被删除但**没有替代**：
///   - 亮度分支整段消失（左半屏上下滑彻底无反应）
///   - 音量基准值被写死成 1.0（不读当前值，一上手就跳满）
///
/// 这里守住通道契约：方法名与参数形状一旦改了，Android 侧会静默失败。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('io.xlist/system_ui');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getVolume':
            case 'getBrightness':
              return 0.5;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getVolume 走 getVolume 方法并返回 0.0-1.0', () async {
    final v = await SystemUiHelper.getVolume();
    expect(calls.single.method, 'getVolume');
    expect(v, 0.5);
  });

  test('setVolume 传 volume 参数（归一化 0.0-1.0，不是 0-100）', () async {
    await SystemUiHelper.setVolume(0.3);
    expect(calls.single.method, 'setVolume');
    expect(calls.single.arguments['volume'], 0.3);
  });

  test('getBrightness 走 getBrightness 方法', () async {
    final v = await SystemUiHelper.getBrightness();
    expect(calls.single.method, 'getBrightness');
    expect(v, 0.5);
  });

  test('setBrightness 传 brightness 参数', () async {
    await SystemUiHelper.setBrightness(0.7);
    expect(calls.single.method, 'setBrightness');
    expect(calls.single.arguments['brightness'], 0.7);
  });

  test('超范围的入参被收敛到 0.0-1.0（避免原生侧越界）', () async {
    await SystemUiHelper.setVolume(1.8);
    await SystemUiHelper.setBrightness(-0.4);
    expect(calls[0].arguments['volume'], 1.0);
    expect(calls[1].arguments['brightness'], 0.0);
  });

  test('返回值为 null 时退化为 0.0 而不是崩', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    expect(await SystemUiHelper.getVolume(), 0.0);
    expect(await SystemUiHelper.getBrightness(), 0.0);
  });
}
