import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:xlist/global.dart';
import 'package:xlist/routes/app_pages.dart';

/// 路由解析器：把 GetX 的 `AppPages.routes`（含 children 嵌套）翻译成
/// 一个**扁平**的 `GetPage` 表，并据此实现 `MaterialApp.onGenerateRoute`。
///
/// ## 为什么不用 go_router
///
/// 原计划是迁 go_router，但实测发现不需要（见 test/routes/getx_nav_shell_test.dart）：
/// 用裸 `MaterialApp(navigatorKey: Get.key, navigatorObservers: [GetObserver()])`
/// 时，GetX 的导航 / `Get.arguments` / binding / 控制器生命周期**全部照常工作**，
/// 包括 pop 时自动销毁路由级控制器。所以 53 处导航调用与 32 处 `Get.arguments`
/// 一行都不用改，也不必引入新的路由库。
///
/// 唯一需要自己补的是 `Get.arguments` 的时序：GetX 原来在 `GetMaterialApp` 里
/// 由 `GetObserver` 在路由创建**之后**写入 `Get.routing.args`，而 binding 在
/// 路由**构建时**就执行了 —— 顺序倒置会让所有在字段初始化里读 `Get.arguments`
/// 的 controller 拿到 null。补法是解析路由前先手动写一次
/// （见 [resolveGetPage] 里的 `Get.routing.args = settings.arguments`）。
///
/// ## 关于 GetMaterialApp
///
/// 之所以不继续用 `GetMaterialApp`，是因为 Phase 3 要升 material_ui，而
/// `GetMaterialApp` 的 `theme:` 参数要求 `package:flutter/material.dart` 的
/// `ThemeData`，material_ui 提供的是**同名不同类**的另一份，会编译失败。
/// 换成 `MaterialApp` 后这条路就通了；GetX 的其余部分都留着。
class AppRouter {
  AppRouter._();

  /// 扁平化后的路由表：`GetPage.name` 是完整路径。
  static final List<GetPage> _flat = _flatten(AppPages.routes);

  /// 全部已知路由路径（供测试与排查用）。
  static List<String> get allPaths =>
      _flat.map((e) => e.name).whereType<String>().toList();

  /// 把 `AppPages.routes` 递归摊平。
  ///
  /// GetX 的 children 语义是**字符串拼接**：父 `/setting` + 子 `/server`
  /// 得到 `/setting/server`（与 `Routes.settingServer` 的定义一致）。
  /// 这里复刻同一规则，保证与原有路由路径逐字相同。
  static List<GetPage> _flatten(List<GetPage> routes) {
    final out = <GetPage>[];

    void walk(GetPage page, String? parent) {
      // unknownRoute 不是真实路由，跳过（由 onUnknownRoute 处理）
      if (identical(page, AppPages.unknownRoute)) return;

      final name = parent == null ? page.name : '$parent${page.name}';

      out.add(GetPage(
        name: name,
        page: page.page,
        binding: page.binding,
        bindings: page.bindings,
        transition: page.transition,
        transitionDuration: page.transitionDuration,
        opaque: page.opaque,
        showCupertinoParallax: page.showCupertinoParallax,
        middlewares: page.middlewares,
        maintainState: page.maintainState,
        fullscreenDialog: page.fullscreenDialog,
        customTransition: page.customTransition,
        curve: page.curve,
        alignment: page.alignment,
        popGesture: page.popGesture,
        title: page.title,
        gestureWidth: page.gestureWidth,
        // 注意：GetPage 没有 barrier* 参数（那些只在 GetPageRoute 上），
        // 项目里也没有用到 barrier 配置。
      ));

      // GetPage.children 默认是空列表（非 null），所以直接遍历
      for (final c in page.children) {
        walk(c, name);
      }
    }

    for (final r in routes) {
      walk(r, null);
    }
    return out;
  }

  /// 按路径查一条路由（与原 `GetMaterialApp.getPages` 的匹配语义一致：
  /// 精确匹配优先；带参数路径按 GetX 的 `:param` 规则匹配）。
  static GetPage? resolve(String? name) {
    if (name == null) return null;

    // 精确匹配
    for (final p in _flat) {
      if (p.name == name) return p;
    }

    // 参数化匹配，如 /detail/:id —— 目前项目未使用，但保留以免将来加路由时静默失效
    for (final p in _flat) {
      final pn = p.name;
      if (!pn.contains(':')) continue;
      if (_matchPattern(pn, name)) return p;
    }
    return null;
  }

  static bool _matchPattern(String pattern, String path) {
    final pp = pattern.split('/');
    final sp = path.split('/');
    if (pp.length != sp.length) return false;
    for (var i = 0; i < pp.length; i++) {
      if (pp[i].startsWith(':')) continue;
      if (pp[i] != sp[i]) return false;
    }
    return true;
  }

  /// `MaterialApp.onGenerateRoute` 的实现。
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final page = resolve(settings.name);
    if (Global.routeLog) {
      // debugPrint（非 print）：release 下 print 的输出在 Android 会被丢弃
      debugPrint('XLIST_GEN >>> name=${settings.name} page=${page?.name}');
    }
    if (page == null) return null;

    // 关键：在跑 binding 之前把参数写进 GetX 的 Routing 对象。
    // 不写的话，controller 里 `Get.arguments['x']` 会在字段初始化时拿到 null
    // （实测：binding / 构造 / onInit / build 四个时点全是 null）。
    // GetMaterialApp 内部替我们做了这件事，换成裸 MaterialApp 要自己补。
    Get.routing.args = settings.arguments;

    return GetPageRoute(
      settings: settings,
      page: page.page,
      binding: page.binding,
      bindings: page.bindings,
      transition: page.transition,
      transitionDuration:
          page.transitionDuration ?? const Duration(milliseconds: 300),
      opaque: page.opaque,
      showCupertinoParallax: page.showCupertinoParallax,
      middlewares: page.middlewares,
      maintainState: page.maintainState,
      fullscreenDialog: page.fullscreenDialog,
      customTransition: page.customTransition,
      curve: page.curve,
      alignment: page.alignment,
      popGesture: page.popGesture,
      title: page.title,
      gestureWidth: page.gestureWidth,
    );
  }

  /// 未匹配路由：用原 `unknownRoute` 指向的页面。
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return GetPageRoute(
      settings: settings,
      page: AppPages.unknownRoute.page,
    );
  }
}
