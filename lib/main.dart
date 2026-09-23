import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:media_kit/media_kit.dart';

import 'package:xlist/global.dart';
import 'package:xlist/themes.dart';
import 'package:xlist/components/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/routes/app_router.dart';
import 'package:xlist/pages/splash/index.dart';
import 'package:xlist/langs/translation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 已发生的 Flutter 框架异常经 debugPrint 打全（含堆栈）。
  //
  // 为什么需要它：真机上播放页会**每帧**刷
  //   Another exception was thrown: Instance of 'SV<void>'
  // 但永远拿不到第一个异常的完整信息 —— Flutter 只对「首个」异常打印完整
  // dump，之后一律退化成错误对象（release 混淆后就是 'SV<void>'）。
  // 而 logcat 缓冲会滚掉首个 dump，导致无法定位。这里把**每一次**框架异常
  // 都经 debugPrint 输出（release 下 `print` 会被丢弃，debugPrint 不会）。
  // 复用 XLIST_MPV_LOG 开关，平时零开销。
  if (const bool.fromEnvironment('XLIST_MPV_LOG')) {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('XLIST_ERR >>> ${details.exception}');
      debugPrint('XLIST_ERR stack:\n${details.stack}');
      previous?.call(details);
    };
  }

  // 词条注册必须在任何 UI 读取 `.tr` 之前 —— 首页/播放页的标题都是 .tr。
  // GetMaterialApp 原先在 onGenerateRoute/initialRoute 里替我们做这件事
  // （实测其源码：`Get.addTranslations(translations!.keys)`），换成裸
  // MaterialApp 后要自己补。
  Get.addTranslations(TranslationService().keys);
  Get.locale = TranslationService.locale;
  Get.fallbackLocale = TranslationService.fallbackLocale;

  Global.init().then((e) {
    // 原 GetMaterialApp.initialBinding 会跑 SplashBinding；
    // 裸 MaterialApp 没有这个钩子，手动执行一次。
    SplashBinding().dependencies();
    runApp(Phoenix(child: XlistApp()));
  });
}

class XlistApp extends StatelessWidget {
  const XlistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(1080, 1920),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'Xlist',
        theme: Themes.light,
        darkTheme: Themes.dark,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,

        // ---- 用裸 MaterialApp 承载 GetX 导航 ----
        //
        // 为什么不用 GetMaterialApp：Phase 3 要引入 material_ui，而
        // GetMaterialApp 的 `theme:` 参数要求 `package:flutter/material.dart`
        // 的 ThemeData；material_ui 给的是**同名不同类**的另一份，会编译失败。
        //
        // 换成裸 MaterialApp 后，GetX 的导航 / Get.arguments / binding /
        // 控制器生命周期仍然全部可用（已由 test/routes/getx_nav_shell_test.dart
        // 逐条验证，含 pop 时控制器被自动销毁、二次进入不拿到陈旧实例）。
        // 所以 53 处导航调用与 32 处 Get.arguments 一行都不用改 ——
        // 原计划的 go_router 迁移（3 周）因此省掉。
        //
        // 三个必需件：
        //   1. navigatorKey: Get.key —— GetX 导航要操作同一个 Navigator
        //   2. navigatorObservers: [GetObserver()] —— 维护 Get.arguments 与
        //      Get.currentRoute；下面的 routing 回调把当前路由同步给
        //      MiniPlayerOverlay（判断是否在播放页）
        //   3. onGenerateRoute / onUnknownRoute —— 由 AppPages.routes 扁平化
        //      而来，路径与迁移前逐字相同（见 test/routes/app_router_test.dart）
        navigatorKey: Get.key,
        navigatorObservers: [
          // 第二个参数 `Get.routing` 是**必须**的，不是可选项：
          // GetObserver 通过 `_routeSend.update(...)` 往这个 Routing 实例里写
          // `args`，而 `Get.arguments` 读的就是同一个对象。少传它 → 所有
          // `Get.arguments['x']` 拿到 null（真机实测：文件夹点击进
          // DetailController 直接 `NoSuchMethodError: [](“path”) on null`）。
          // GetMaterialApp 内部就是 `GetObserver(routingCallback, Get.routing)`。
          GetObserver(
            (routing) {
              currentRoute.value = routing?.current ?? '';
              if (Global.routeLog) {
                // 用 debugPrint（非 print）：release 下 print 的输出在 Android
                // 会被丢掉，debugPrint 才能进 logcat。
                debugPrint('XLIST_ROUTE >>> ${routing?.current}');
              }
            },
            Get.routing,
          ),
        ],
        initialRoute: AppPages.initial,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,

        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.0)),
            // 主题桥接：给已迁 material_ui 的包（smart_dialog / cached_network_image /
            // flex_color_scheme / dynamic_color …）提供 material_ui 版主题。
            // 不架这层的话，那些包内的 `Theme.of` 会**静默拿到 fallback 默认主题**
            // （不报错，颜色变默认紫）—— 见 lib/components/theme_bridge.dart。
            child: ThemeBridge(
              // 5.3.0 里 `init` 仍挂在 `FlutterSmartDialog` 上（类名没改，
              // 只有 `smart_dialog.dart` 里那个独立类叫 SmartDialog）。
              child: FlutterSmartDialog.init(
                toastBuilder: (String msg) => ToastComponent(message: msg),
              )(
                context,
                // 迷你播放条：覆盖在所有页面之上，全屏播放页自身不显示
                //
                // 必须用 StackFit.expand（等价于给两个子节点紧约束）：
                // Stack 默认给非定位子节点**松约束**，app 子树的 Scaffold 会按
                // 内容大小收缩，表现为「页面不满屏、背景发黑」。
                //
                // 注：smart_dialog 的 initState 只在 child 是 Navigator/FocusScope
                // 时才能拿到 contextNavigator；传 Stack 会拿不到，但实测 toast /
                // loading / dialog 仍正常显示（它自己那层 Overlay 才是真正的宿主）。
                Stack(
                  fit: StackFit.expand,
                  children: [
                    child ?? const SizedBox.shrink(),
                    const MiniPlayerOverlay(),
                  ],
                ),
              ),
            ),
          );
        },

        // ---- i18n ----
        //
        // GetMaterialApp 认 translations/locale/fallbackLocale 三个参数，
        // 裸 MaterialApp 不认（它们不是 MaterialApp 的参数），所以已在 main()
        // 里用 Get.addTranslations 手动注册。
        //
        // 这一组 delegate 是**必需**的，不是可选优化：
        // `DefaultMaterialLocalizations` 只提供英文。若 supportedLocales 里声明了
        // zh_Hans 却只挂 Default* delegate，设备为中文时语言解析会落到 zh，
        // 而该 delegate 的 isSupported 不认 zh —— 于是 Localizations 里没有
        // MaterialLocalizations，`MaterialLocalizations.of()` 返回 null，
        // AlertDialog / 日期选择器 / 长按菜单里的 `!` 断言直接崩
        // （真机实测：`Null check operator used on a null value` →
        //  MaterialLocalizations.of → AlertDialog.build）。
        //
        // 取自 ThemeBridge，与桥接层共用同一份（桥接层内还会再挂一次 —— 因为
        // `Localizations` 是遮蔽而非叠加，层内看不到层外的 delegate）。
        localizationsDelegates: ThemeBridge.localizationsDelegates,
        supportedLocales: ThemeBridge.supportedLocales,
      ),
    );
  }
}
