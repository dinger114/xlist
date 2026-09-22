import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 回归测试：裸 MaterialApp 上 `Get.arguments` 的接线。
///
/// 背景（真机实测的崩溃）：
/// Phase 1 把 `GetMaterialApp` 换成 `MaterialApp(navigatorKey: Get.key,
/// navigatorObservers: [GetObserver(cb)])` 后，点文件夹进详情页直接崩：
///
///     NoSuchMethodError: The method '[]' was called on null.
///     Tried calling: []("path")
///     #2 new DetailController (lib/pages/detail/controller.dart:26)
///
/// 根因：`GetObserver` 是 `GetObserver([this.routing, this._routeSend])`，
/// **第二个**位置参数 `_routeSend` 才是被写入 `args` 的那个 `Routing` 对象，
/// 而 `Get.arguments` 读的正是它。只传回调不传 `Get.routing` → 没有任何人
/// 往那个实例里写 args → 所有 `Get.arguments['x']` 都是 null。
/// `GetMaterialApp` 内部是 `GetObserver(routingCallback, Get.routing)`。
///
/// 这些测试直接用生产接线方式搭建，不手动 set `Get.routing.args`，
/// 所以能真的钉住这个坑。
void main() {
  tearDown(Get.reset);

  Widget shell({required bool wireRouteSend}) => MaterialApp(
        navigatorKey: Get.key,
        navigatorObservers: [
          if (wireRouteSend) GetObserver(null, Get.routing) else GetObserver(),
        ],
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Column(
              children: [
                // 走 `Get.to(builder, arguments:)` —— 生产里 ObjectHelper.click
                // 打开文件夹用的就是这个形态（不是命名路由）。
                TextButton(
                  onPressed: () => Get.to(
                    () => const _ArgsProbe(),
                    routeName: '/detail_xxx',
                    arguments: {'path': '/a/b', 'name': 'c'},
                  ),
                  child: const Text('TO_BUILDER'),
                ),
                // 走命名路由 + onGenerateRoute（覆盖另一条路径）
                TextButton(
                  onPressed: () => Get.toNamed('/named_probe',
                      arguments: {'path': '/n', 'name': 'm'}),
                  child: const Text('TO_NAMED'),
                ),
              ],
            ),
          ),
        ),
        onGenerateRoute: (s) => s.name == '/named_probe'
            ? GetPageRoute(settings: s, page: () => const _ArgsProbe())
            : null,
      );

  testWidgets('Get.to(builder, arguments:) + Get.routing 接线时，Controller 能读到参数',
      (tester) async {
    await tester.pumpWidget(shell(wireRouteSend: true));
    await tester.tap(find.text('TO_BUILDER'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '进页面时抛异常');
    expect(find.text('path=/a/b'), findsOneWidget);
    expect(find.text('name=c'), findsOneWidget);
  });

  testWidgets('命名路由路径同样能读到参数', (tester) async {
    await tester.pumpWidget(shell(wireRouteSend: true));
    await tester.tap(find.text('TO_NAMED'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('path=/n'), findsOneWidget);
    expect(find.text('name=m'), findsOneWidget);
  });

  testWidgets('对照：漏传 Get.routing（旧写法）时 Get.arguments 为 null —— 说明此参数必需',
      (tester) async {
    await tester.pumpWidget(shell(wireRouteSend: false));
    await tester.tap(find.text('TO_BUILDER'));
    // 控制器在字段初始化里读 Get.arguments，会抛错；这里只观察参数是否为 null
    await tester.pumpAndSettle().catchError((_) {});
    tester.takeException();

    debugPrint('>>> 漏传 Get.routing 时 Get.arguments = ${Get.arguments}');
    expect(
      Get.arguments,
      anyOf(isNull, equals(<String, dynamic>{})),
      reason: '若这里不再是 null，说明 GetX 改了行为，上面的注释需要更新',
    );
  });
}

/// 复刻生产 controller 的读取姿势：**字段初始化**时就读 `Get.arguments`。
class _ArgsProbe extends StatelessWidget {
  const _ArgsProbe();

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map?;
    return Scaffold(
      body: Column(
        children: [
          Text('path=${args?['path']}'),
          Text('name=${args?['name']}'),
        ],
      ),
    );
  }
}
