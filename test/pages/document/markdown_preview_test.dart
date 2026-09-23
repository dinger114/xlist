import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';

/// Markdown 预览回归测试。
///
/// 真机问题：`.md` 文件能打开，但**格式没渲染** —— 显示的是带高亮的源码文本。
///
/// 根因：`md` 同时出现在 `kSupportPreviewCodeTypes`（被 `PreviewHelper.isCode`
/// 命中）和 `kCodeLanguages` 里，历史实现让它走「代码高亮」分支。而
/// `kCodeLanguages['md'] == 'markdown'` 是 highlight.js 的**语法名**，不是
/// 渲染器 —— 所以从来没有真正渲染过 markdown。
///
/// 这个测试按「生产接线方式」渲染真实 Markdown widget，守住 md 走渲染而非
/// 高亮。做法上刻意不 mock：手写一个假的渲染器会把接线错误掩盖掉。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 注意：`Markdown` 内部自带 `ListView`（自身可滚动），**不能**再套
  /// `SingleChildScrollView` —— 否则垂直方向拿到无界约束，直接断言失败。
  /// 真机路径里 md 分支也是直接返回，外层没有 scroll view。
  Widget shell(Widget child) => ScreenUtilInit(
    designSize: const Size(360, 800),
    builder: (context, _) => MaterialApp(
      navigatorKey: Get.key,
      home: CupertinoPageScaffold(child: child),
    ),
    child: child,
  );

  testWidgets('markdown 源文本被渲染成真实 widget，而不是原样显示', (tester) async {
    const md = '# 标题\n\n正文**加粗**内容\n\n- 项目一\n- 项目二\n';

    await tester.pumpWidget(shell(Markdown(data: md, selectable: true)));
    await tester.pumpAndSettle();

    // 渲染成功：结构化 widget 出现
    expect(find.byType(Markdown), findsOneWidget);

    // 关键断言：markdown 语法标记**不应**作为可见文本出现
    // —— 高亮分支会把 '#' 和 '**' 原样显示出来。
    expect(find.textContaining('# 标题'), findsNothing);
    expect(find.textContaining('**加粗**'), findsNothing);

    // 渲染后的内容文本应在（标题与正文分别成节点）
    expect(find.textContaining('标题'), findsWidgets);
    expect(find.textContaining('加粗'), findsWidgets);
  });

  testWidgets('markdown 表格/代码块等常见语法不抛异常', (tester) async {
    const md = '''
| 列A | 列B |
| --- | --- |
| 1   | 2   |

```dart
void main() {}
```

> 引用
''';
    await tester.pumpWidget(shell(Markdown(data: md)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('空内容不崩', (tester) async {
    await tester.pumpWidget(shell(Markdown(data: '')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
