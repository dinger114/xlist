import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'package:xlist/components/theme_bridge.dart';
import 'package:xlist/themes.dart';

/// 主题桥接的回归测试。
///
/// 背景（这是 Phase 3 最容易翻车、且**不会报错**的地方）：
/// `flutter/material.dart` 与 `material_ui/material_ui.dart` 各有自己的
/// `ThemeData`，彼此的 `Theme.of()` 找不到对方时**静默返回
/// `ThemeData.fallback()`** —— 不抛异常，只是颜色变成默认紫。
///
/// 所以判据不能是「没崩」，必须**比对颜色**：cross-library 读到的主题，
/// 其 primary 必须等于我们的品牌色，而不是 fallback 的默认色。
///
/// 本项目只有 5 个包已迁 material_ui，约 50 个仍用 flutter/material，
/// 因此主壳保持 flutter 主题 + `ThemeBridge` 补一层 material_ui 主题。
void main() {
  /// fallback 的 primary（两个库的 fallback 恰好同色，实测确认过）
  final fallbackPrimary = mui.ThemeData.fallback().colorScheme.primary;

  group('主题桥接', () {
    testWidgets('material_ui 侧通过桥接读到的是品牌主色，不是 fallback', (tester) async {
      late mui.ColorScheme got;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          builder: (ctx, child) => ThemeBridge(child: child!),
          home: Builder(
            builder: (ctx) {
              got = mui.Theme.of(ctx).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        got.primary.toARGB32(),
        Themes.brand.toARGB32(),
        reason:
            'material_ui 侧拿到的不是品牌色 —— 桥接没生效，'
            '它静默退回了 fallback（这正是最难发现的那种失败）',
      );
      expect(
        got.primary.toARGB32(),
        isNot(fallbackPrimary.toARGB32()),
        reason: 'material_ui 侧读到的是 fallback 主题',
      );
    });

    testWidgets('没有桥接时会静默退回 fallback（说明这层不是可选的）', (tester) async {
      late mui.ColorScheme got;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          home: Builder(
            builder: (ctx) {
              got = mui.Theme.of(ctx).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      // 记录「不架桥会怎样」：不报错，只是主题不对。
      expect(
        got.primary.toARGB32(),
        fallbackPrimary.toARGB32(),
        reason:
            '若这里不再是 fallback，说明 Flutter 改了跨库行为，'
            'ThemeBridge 的必要性需要重新评估',
      );
    });

    testWidgets('桥接不会吃掉 flutter 侧主题（两套并存）', (tester) async {
      late ColorScheme gotFlutter;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          builder: (ctx, child) => ThemeBridge(child: child!),
          home: Builder(
            builder: (ctx) {
              gotFlutter = Theme.of(ctx).colorScheme;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(gotFlutter.primary.toARGB32(), Themes.brand.toARGB32());
    });

    testWidgets('flutter 与 material_ui 的 widget 可在同一棵树里共存', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          builder: (ctx, child) => ThemeBridge(child: child!),
          home: Scaffold(
            appBar: AppBar(title: const Text('flutter appbar')),
            body: Column(
              children: [
                const Text('flutter text'),
                mui.ElevatedButton(
                  onPressed: () {},
                  child: const mui.Text('material_ui button'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));

      expect(tester.takeException(), isNull);
      expect(find.text('flutter text'), findsOneWidget);
      expect(find.text('material_ui button'), findsOneWidget);
    });
  });

  group('主题一致性', () {
    test('flutter 版与 material_ui 版主色一致', () {
      expect(
        Themes.light.colorScheme.primary.toARGB32(),
        Themes.muiLight.colorScheme.primary.toARGB32(),
      );
      expect(
        Themes.dark.colorScheme.primary.toARGB32(),
        Themes.muiDark.colorScheme.primary.toARGB32(),
      );
    });

    test('两套主题都是品牌色（没有被 flex9 的默认方案覆盖）', () {
      expect(
        Themes.light.colorScheme.primary.toARGB32(),
        Themes.brand.toARGB32(),
      );
      expect(
        Themes.dark.colorScheme.primary.toARGB32(),
        Themes.brand.toARGB32(),
      );
    });

    test('亮/暗主题的 brightness 正确', () {
      expect(Themes.light.brightness, Brightness.light);
      expect(Themes.dark.brightness, Brightness.dark);
      expect(Themes.muiLight.brightness, Brightness.light);
      expect(Themes.muiDark.brightness, Brightness.dark);
    });

    test('flex_color_scheme 9 的 ThemeData 确实是 material_ui 版', () {
      // 编译期即证明：若写成 flutter 版，这里的赋值就过不去
      final mui.ThemeData asMui = Themes.muiLight;
      expect(asMui.colorScheme, isNotNull);
    });

    test('scaffoldBackgroundColor 有从 material_ui 侧搬过来', () {
      expect(Themes.light.scaffoldBackgroundColor, isNotNull);
      expect(
        Themes.light.scaffoldBackgroundColor.toARGB32(),
        Themes.muiLight.scaffoldBackgroundColor.toARGB32(),
        reason: '两套主题的页面底色应一致',
      );
    });
  });

  group('本地化桥接（smart_dialog 5.3 的 dialog 必需）', () {
    testWidgets('mui 的 MaterialLocalizations 通过桥接可取到', (tester) async {
      late mui.MaterialLocalizations? got;
      Object? caught;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          builder: (ctx, child) => ThemeBridge(child: child!),
          home: Builder(
            builder: (ctx) {
              try {
                got = mui.MaterialLocalizations.of(ctx);
              } catch (e) {
                caught = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        caught,
        isNull,
        reason:
            '取 mui MaterialLocalizations 抛异常了 —— smart_dialog 的 '
            'dialog 会直接崩（No MaterialLocalizations found.）',
      );
      expect(got, isNotNull);
    });

    testWidgets('没有桥接时取不到 mui 的 MaterialLocalizations（说明这层必需）', (tester) async {
      Object? caught;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          home: Builder(
            builder: (ctx) {
              try {
                mui.MaterialLocalizations.of(ctx);
              } catch (e) {
                caught = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        caught,
        isNotNull,
        reason:
            '若这里不再抛异常，说明 mui 的本地化变得可继承，'
            'ThemeBridge 里那层 Localizations 需要重新评估',
      );
    });

    testWidgets('中文 locale 下也能取到（对齐主壳的 zh_Hans）', (tester) async {
      late mui.MaterialLocalizations? got;
      Object? caught;
      await tester.pumpWidget(
        MaterialApp(
          theme: Themes.light,
          locale: const Locale('zh', 'Hans'),
          builder: (ctx, child) => ThemeBridge(child: child!),
          home: Builder(
            builder: (ctx) {
              try {
                got = mui.MaterialLocalizations.of(ctx);
              } catch (e) {
                caught = e;
              }
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(caught, isNull, reason: 'zh_Hans 下取不到 mui 本地化');
      expect(got, isNotNull);
    });
  });
}
