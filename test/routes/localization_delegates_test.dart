import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 回归测试：Material 本地化 delegate 与 supportedLocales 必须配套。
///
/// 背景（真机实测的崩溃）：Phase 1 把 `GetMaterialApp` 换成裸 `MaterialApp`
/// 时，一开始只挂了 `DefaultMaterialLocalizations`，而 `supportedLocales` 里
/// 声明了 `zh_Hans`。设备语言是中文时语言解析落到 zh，但 Default* delegate
/// 的 `isSupported` 不认 zh —— Localizations 里就没有 MaterialLocalizations，
/// `MaterialLocalizations.of()` 返回 null，AlertDialog 里的 `!` 直接崩：
///
///     Null check operator used on a null value
///     #0 MaterialLocalizations.of
///     #1 AlertDialog.build
///
/// 这类问题只在真机中文环境下出现（英文或纯 en 的测试都发现不了），
/// 所以在 CI 里用 zh locale 把它钉住。
void main() {
  /// 与 lib/main.dart 中一致的 delegate 组合
  const delegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ];

  const supported = [Locale('en', 'US'), Locale('zh', 'Hans')];

  Widget app(Locale locale, {required List<LocalizationsDelegate> dels}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: dels,
        supportedLocales: supported,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showDialog(
              context: ctx,
              builder: (_) => const AlertDialog(title: Text('DIALOG_OK')),
            ),
            child: const Text('OPEN'),
          ),
        ),
      );

  testWidgets(
    'zh_Hans：AlertDialog 能正常弹出（不再因 MaterialLocalizations 为 null 崩溃）',
    (tester) async {
      await tester.pumpWidget(app(const Locale('zh', 'Hans'), dels: delegates));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'zh locale 下弹对话框抛异常 —— MaterialLocalizations 缺失',
      );
      expect(find.text('DIALOG_OK'), findsOneWidget);
    },
  );

  testWidgets('zh_CN（设备常见写法）：同样正常', (tester) async {
    await tester.pumpWidget(app(const Locale('zh', 'CN'), dels: delegates));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DIALOG_OK'), findsOneWidget);
  });

  testWidgets('en_US：正常', (tester) async {
    await tester.pumpWidget(app(const Locale('en', 'US'), dels: delegates));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DIALOG_OK'), findsOneWidget);
  });

  testWidgets('对照：缺少 Global* delegate 时 zh 会崩（说明这一组不是可有可无）', (tester) async {
    await tester.pumpWidget(
      app(
        const Locale('zh', 'Hans'),
        dels: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // 这个断言记录「为什么会崩」：一旦哪天 Flutter 让 Default* 支持 zh，
    // 这条会失败并提醒我们上面那些测试的前提变了。
    expect(
      tester.takeException(),
      isNotNull,
      reason: 'Default* delegate 竟能支持 zh —— 注释中的前提需要更新',
    );
  });

  testWidgets('MaterialLocalizations 在 zh 下确实可取到（直接断言根因）', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'Hans'),
        localizationsDelegates: delegates,
        supportedLocales: supported,
        home: Builder(
          builder: (ctx) {
            captured = ctx;
            return const Text('X');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      MaterialLocalizations.of(captured),
      isNotNull,
      reason: 'zh 下取不到 MaterialLocalizations —— AlertDialog 必然崩',
    );
  });
}
