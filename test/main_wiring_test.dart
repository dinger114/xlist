import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'package:xlist/themes.dart';
import 'package:xlist/components/index.dart';

/// 按 `lib/main.dart` 的**实际接线**验证 smart_dialog 5.3（material_ui 版）能用。
///
/// 为什么要这个测试：smart_dialog 5.3 是 material_ui 包，它弹 dialog 时会走
/// `mui.MaterialLocalizations.of(context)`。若桥接层只补了主题没补本地化，
/// 真机上就是 `No MaterialLocalizations found.` —— 这个错误在 analyze / 单测
/// 的常规覆盖里抓不到，只能靠「按生产接线跑一遍」抓（本测试就是干这个的）。
///
/// 同时覆盖主题：toast 是用 mui widget 画的，必须能读到 mui 主题（品牌色），
/// 而不是 `ThemeData.fallback()`。
void main() {
  /// 复刻 main.dart 的 builder 链（顺序与参数一致）
  Widget buildApp({required Widget home}) => ScreenUtilInit(
    designSize: const Size(1080, 1920),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      theme: Themes.light,
      darkTheme: Themes.dark,
      themeMode: ThemeMode.light,
      localizationsDelegates: ThemeBridge.localizationsDelegates,
      supportedLocales: ThemeBridge.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          child: ThemeBridge(
            child:
                FlutterSmartDialog.init(
                  toastBuilder: (String msg) => ToastComponent(message: msg),
                )(
                  context,
                  Stack(
                    fit: StackFit.expand,
                    children: [child ?? const SizedBox.shrink()],
                  ),
                ),
          ),
        );
      },
      home: home,
    ),
  );

  testWidgets('toast 能弹出（走生产接线）', (tester) async {
    await tester.pumpWidget(
      buildApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SmartDialog.showToast('toast-ok'),
                child: const Text('T'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull, reason: 'init 阶段异常');

    await tester.tap(find.text('T'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull, reason: '弹 toast 异常');
    expect(find.text('toast-ok'), findsOneWidget);

    // 收尾：toast 内部有 2s 串行定时器（ToastTool._scheduleSerialTimer），
    // 必须 pump 足够时长让它自然结束，否则测试会以 `Pending timers` 失败
    // —— 那是测试收尾问题，不是功能问题。
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('dialog 能弹出（5.3 的 dialog 需要 mui 本地化，这曾是真机崩溃点）', (tester) async {
    await tester.pumpWidget(
      buildApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => SmartDialog.show(
                  builder: (_) => const AlertDialog(title: Text('dialog-ok')),
                ),
                child: const Text('D'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('D'));
    await tester.pump(const Duration(milliseconds: 400));

    final err = tester.takeException();
    expect(
      err,
      isNull,
      reason:
          '弹 dialog 抛异常 —— 若是 No MaterialLocalizations found.，'
          '说明 ThemeBridge 的本地化 delegate 没生效',
    );
    expect(find.text('dialog-ok'), findsOneWidget);

    SmartDialog.dismiss();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('loading 能显示/关闭（51 处 SmartDialog.dismiss 之一）', (tester) async {
    await tester.pumpWidget(
      buildApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  SmartDialog.showLoading();
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  SmartDialog.dismiss();
                },
                child: const Text('L'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('L'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'showLoading 异常');

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'dismiss 异常');
  });

  testWidgets('mui 主题通过生产接线可达（toast 由 mui widget 绘制）', (tester) async {
    late mui.ColorScheme got;
    await tester.pumpWidget(
      buildApp(
        home: Builder(
          builder: (ctx) {
            got = mui.Theme.of(ctx).colorScheme;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));

    expect(
      got.primary.toARGB32(),
      Themes.brand.toARGB32(),
      reason: 'mui 侧没拿到品牌色 —— toast/dialog 会用 fallback 主题绘制',
    );
  });
}
