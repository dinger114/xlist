import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/routes/app_router.dart';
import 'package:xlist/pages/notfound/index.dart';

/// 全量路由测试：把「53 处导航调用都能落到目标页」变成确定性检查。
///
/// 为什么需要它：真机只能靠像素/日志间接判断（Flutter 渲染到 canvas，
/// uiautomator 读不到文本），而且一个个点无法覆盖全部 20 条路由。
/// 这里直接拿生产的 `AppRouter` 走一遍。
///
/// 关于「页面能不能真正构建」：本项目所有业务页都在 binding/onInit 里依赖
/// **完整 DI**（UserStorage / PreferencesStorage / DatabaseService /
/// DownloadService …）并直接打网络（Dio 请求 alist）。单元测试里搭齐这一套
/// 会变成一个假的集成测试，且失败信息无法区分「路由坏了」和「环境缺件」。
/// 所以这里只对**不依赖 DI** 的页面做真实构建（splash / notfound），
/// 其余页面用「onGenerateRoute 返回的 Route 是否正确」来断言 ——
/// 这才是 Phase 1 实际改动的那一层。
void main() {
  final allPaths = AppRouter.allPaths;

  group('路由表完整性', () {
    test('AppRouter 把 AppPages.routes 摊平后非空', () {
      expect(allPaths, isNotEmpty);
    });

    test('unknownRoute 不进路由表（由 onUnknownRoute 兜底）', () {
      expect(allPaths.contains(Routes.NOTFOUND), isFalse,
          reason: '/notfound 是 unknownRoute 的页面，应由 onUnknownRoute 兜底');
    });

    test('全部 Routes 常量都已注册（防漏注册/多余项）', () {
      const expected = [
        Routes.SPLASH,
        Routes.HOMEPAGE,
        Routes.DETAIL,
        Routes.SEARCH,
        Routes.DIRECTORY,
        Routes.DOCUMENT,
        Routes.FILE,
        Routes.IMAGE_PREVIEW,
        Routes.VIDEO_PLAYER,
        Routes.AUDIO_PLAYER,
        Routes.SETTING,
        Routes.SETTING_SERVER,
        Routes.SETTING_DOWNLOAD,
        Routes.SETTING_ABOUT,
        Routes.SETTING_RECENT,
        Routes.SETTING_FAVORITE,
        Routes.SETTING_PREVIEW_IMAGE,
        Routes.SETTING_PREVIEW_AUDIO,
        Routes.SETTING_PREVIEW_VIDEO,
        Routes.SETTING_PREVIEW_DOCUMENT,
      ];

      final missing = expected.where((e) => !allPaths.contains(e)).toList();
      expect(missing, isEmpty, reason: '这些路由没在表里：$missing');

      final extra = allPaths.where((p) => !expected.contains(p)).toList();
      expect(extra, isEmpty, reason: '路由表里有多余项：$extra');
    });

    test('嵌套子路由按 GetX 的字符串拼接语义展开（/setting + /server）', () {
      expect(Routes.SETTING_SERVER, '/setting/server');
      expect(allPaths, contains(Routes.SETTING_SERVER));
    });

    test('每个路径都能解析出 GetPage，且 name 与请求路径逐字一致', () {
      for (final p in allPaths) {
        final page = AppRouter.resolve(p);
        expect(page, isNotNull, reason: '$p 解析不出来');
        expect(page!.name, p, reason: '$p 解析到的却是 ${page.name}');
      }
    });

    test('未知路径解析为 null（交给 onUnknownRoute）', () {
      expect(AppRouter.resolve('/definitely/not/a/route'), isNull);
      expect(AppRouter.resolve(null), isNull);
    });
  });

  group('onGenerateRoute 为每条路由返回正确的 Route', () {
    tearDown(() => Get.routing.args = null);

    test('全部路由都能生成 Route，name 与请求一致', () {
      for (final p in allPaths) {
        final route = AppRouter.onGenerateRoute(RouteSettings(name: p));
        expect(route, isNotNull, reason: '$p 生成不了 Route');
        expect(route, isA<GetPageRoute>(), reason: '$p 生成的不是 GetPageRoute');
        expect(route!.settings.name, p, reason: '$p 的 Route name 不对');
      }
    });

    test('未知路径返回 null（让 onUnknownRoute 接管）', () {
      expect(
        AppRouter.onGenerateRoute(const RouteSettings(name: '/nope/nope')),
        isNull,
      );
    });

    test('onUnknownRoute 指向 notfound 页面', () {
      final route =
          AppRouter.onUnknownRoute(const RouteSettings(name: '/nope'));
      expect(route, isA<GetPageRoute>());
    });

    test('参数在生成 Route 时就写进 Get.routing（binding 构建时就要读）', () {
      // Phase 1 最容易踩的坑：GetMaterialApp 原本在路由创建**之后**由
      // GetObserver 写 args，而 binding 在路由**构建时**就执行了 ——
      // 顺序倒置会让字段初始化里读 Get.arguments 的 controller 全拿到 null。
      Get.routing.args = null;
      AppRouter.onGenerateRoute(RouteSettings(
        name: Routes.HOMEPAGE,
        arguments: {'path': '/p', 'name': 'n'},
      ));
      expect(Get.routing.args, {'path': '/p', 'name': 'n'});
    });
  });

  group('不依赖 DI 的页面能真正构建', () {
    setUp(Get.reset);
    tearDown(Get.reset);

    Widget appAt(String route) => ScreenUtilInit(
          // 与 lib/main.dart 一致：页面里大量 `10.r` / `50.sp` 依赖 ScreenUtil
          // 初始化，缺了会抛 LateInitializationError（不是路由问题）。
          designSize: const Size(1080, 1920),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MaterialApp(
            navigatorKey: Get.key,
            navigatorObservers: [GetObserver(null, Get.routing)],
            initialRoute: route,
            onGenerateRoute: AppRouter.onGenerateRoute,
            onUnknownRoute: AppRouter.onUnknownRoute,
          ),
        );

    testWidgets('splash 能构建', (tester) async {
      await tester.pumpWidget(appAt(Routes.SPLASH));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('push 未知路由会落到 notfound 页面', (tester) async {
      // 注意：不能用 initialRoute 测。Flutter 对**初始路由**不认识时只会
      // 打印 "Could not navigate to initial route" 并回退到 "/"，
      // 不走 onUnknownRoute（真机上 initialRoute 恒为 "/"，所以不受影响）。
      // onUnknownRoute 只在 pushNamed 未知路由时生效 —— 这才对应生产里
      // 「某处路由名写错」的场景。
      await tester.pumpWidget(appAt(Routes.SPLASH));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);

      Get.toNamed('/definitely/not/a/route');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'push 未知路由抛异常了');
      expect(find.byType(NotfoundPage), findsOneWidget,
          reason: '未知路由没有落到 notfound 页面');
    });
  });
}
