import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// 透视测试（稳定版，替代真机像素取证）：
/// 「不用 GetMaterialApp 时，GetX 导航 / 参数 / binding 生命周期还能用吗？」
///
/// 这是决定 Phase 1 做法的关键问题：
///   - 若可用 → 主壳只要换成 MaterialApp + navigatorKey: Get.key，
///     53 处导航调用与 32 处 Get.arguments **全部不用动**，go_router 不需要，
///     3 周工期可省。
///   - 若不可用 → 按计划迁 go_router（本文件即为该方案的对照基线）。
///
/// 用 widget test 而非真机，是因为要断言的正是「控制器生命周期」这种
/// 像素看不出来的东西（onClose 是否在 pop 时触发）。
void main() {
  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets('MaterialApp + navigatorKey: Get.key 下 GetX 导航全链路', (
    tester,
  ) async {
    Get.reset();
    ProbeController.lifecycle.clear();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Get.key,
        navigatorObservers: [GetObserver()],
        onGenerateRoute: probeOnGenerateRoute,
        home: const ProbeFirstPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 第一页在
    expect(find.text('PROBE_FIRST'), findsOneWidget);

    // 1. Get.toNamed 能否跳转
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(
      find.text('PROBE_SECOND'),
      findsOneWidget,
      reason: 'Get.toNamed 未生效',
    );

    // 2. Get.arguments 能否取到
    expect(
      find.textContaining('arg=第一次'),
      findsOneWidget,
      reason: 'Get.arguments 未传递到新页面',
    );

    // 3. binding 是否被调用（控制器是否创建）
    expect(Get.isRegistered<ProbeController>(), isTrue, reason: 'binding 未执行');
    expect(
      ProbeController.lifecycle.any((e) => e.startsWith('onInit')),
      isTrue,
    );

    // 4. Get.back 返回后，控制器是否被销毁（关键！）
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    expect(find.text('PROBE_FIRST'), findsOneWidget, reason: 'Get.back 未生效');

    debugPrint('>>> 生命周期: ${ProbeController.lifecycle}');
    debugPrint('>>> pop 后是否仍注册: ${Get.isRegistered<ProbeController>()}');
    expect(
      ProbeController.lifecycle.any((e) => e.startsWith('onClose')),
      isTrue,
      reason: 'pop 后控制器未销毁 —— 再次进入会拿到陈旧实例',
    );
    expect(
      Get.isRegistered<ProbeController>(),
      isFalse,
      reason: 'pop 后控制器仍注册在容器里',
    );
  });

  testWidgets('对照：第二次进入应拿到全新实例（不是陈旧实例）', (tester) async {
    Get.reset();
    ProbeController.lifecycle.clear();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Get.key,
        navigatorObservers: [GetObserver()],
        onGenerateRoute: probeOnGenerateRoute,
        home: const ProbeFirstPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 第一次
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('arg=第一次'), findsOneWidget);
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    // 第二次（带不同参数）
    await tester.tap(find.text('GO2'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('arg=第二次'),
      findsOneWidget,
      reason: '第二次进入拿到了陈旧参数/陈旧控制器',
    );
  });
}

/// ---- 探针页面与控制器 ----

class ProbeController extends GetxController {
  static final lifecycle = <String>[];

  final String arg = Get.arguments?['tag'] ?? '(无参数)';

  @override
  void onInit() {
    super.onInit();
    lifecycle.add('onInit:$arg');
  }

  @override
  void onClose() {
    lifecycle.add('onClose:$arg');
    super.onClose();
  }
}

class ProbeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProbeController>(ProbeController());
  }
}

class ProbeFirstPage extends StatelessWidget {
  const ProbeFirstPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('PROBE_FIRST'),
          TextButton(
            onPressed: () => Get.toNamed('/probe', arguments: {'tag': '第一次'}),
            child: const Text('GO'),
          ),
          TextButton(
            onPressed: () => Get.toNamed('/probe', arguments: {'tag': '第二次'}),
            child: const Text('GO2'),
          ),
        ],
      ),
    );
  }
}

class ProbeSecondPage extends StatelessWidget {
  const ProbeSecondPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ProbeController>();
    return Scaffold(
      body: Column(
        children: [
          const Text('PROBE_SECOND'),
          Text('arg=${c.arg}'),
          TextButton(onPressed: () => Get.back(), child: const Text('BACK')),
        ],
      ),
    );
  }
}

Route<dynamic>? probeOnGenerateRoute(RouteSettings settings) {
  if (settings.name != '/probe') return null;
  // 必需的一行：GetX 的 Get.arguments 由 GetObserver 在路由**创建之后**才写入，
  // 而 binding 在 route 构建时执行 —— 顺序倒置会让所有 controller
  // （读 Get.arguments 的字段初始化）拿到 null。
  // GetMaterialApp 里是它内部替我们做了等价的事；换成裸 MaterialApp 后要自己补。
  Get.routing.args = settings.arguments;
  return GetPageRoute(
    settings: settings,
    page: () => const ProbeSecondPage(),
    binding: ProbeBinding(),
  );
}
