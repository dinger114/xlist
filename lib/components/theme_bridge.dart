import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as f;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'package:xlist/themes.dart';

/// 主题 + 本地化桥接层。
///
/// ## 为什么需要它
///
/// `flutter/material.dart` 与 `material_ui/material_ui.dart` 是**两套完全独立**的
/// Material 实现，各自的 `ThemeData` 与 `MaterialLocalizations` 互不认识。
/// 而「找不到」的表现是**静默降级**，不会报错：
///
/// - `mui.Theme.of(ctx)` 找不到 mui 主题 → 返回 `ThemeData.fallback()`（默认紫）
/// - `mui.MaterialLocalizations.of(ctx)` 找不到 mui 本地化 → 抛
///   `No MaterialLocalizations found.`（smart_dialog 5.3 的 dialog 走这条，
///   实测：只架主题桥接时 dialog 仍崩，就是这个原因）
///
/// 本项目 5 个包已迁 material_ui（flutter_smart_dialog 5 / cached_network_image 4 /
/// flex_color_scheme 9 / dynamic_color 2 / animations 3），约 50 个仍用
/// flutter/material。所以主壳保持 flutter 侧，由本 widget 在
/// `MaterialApp.builder` 上把 **mui 侧的主题与本地化**补上。
///
/// ## 关键坑：`Localizations` 是「遮蔽」而非「叠加」
///
/// [Localizations] 是 `InheritedWidget`，在它之下 `Localizations.of` 找的是
/// **它自己声明的**那套，上层 MaterialApp 的 delegate 不再可见。
/// 实测：若本层只挂 mui 的 delegate，桥接层**之下**的 flutter widget
/// （`AppBar` 等）会立刻报 `No MaterialLocalizations found.`。
/// 所以本层必须同时提供**两侧**的 delegate —— 见 [localizationsDelegates]。
///
/// [localizationsDelegates] 是唯一真源：主壳 `MaterialApp` 与本层共用它，
/// 保证「层外」与「层内」看到的本地化完全一致。
///
/// ## 实测结论（探针工程 + test/components/theme_bridge_test.dart，非推断）
///
/// - 桥接后 mui 侧 `Theme.of` 读到品牌色，不再是 fallback
/// - 桥接**不会**吃掉 flutter 侧主题（层内 `f.Theme.of` 仍是 flutter 主题）
/// - 两侧 widget 可互相嵌套、正常构建
/// - smart_dialog 5.3 的 **toast** 不依赖 MaterialLocalizations；**dialog** 依赖
class ThemeBridge extends StatelessWidget {
  const ThemeBridge({super.key, required this.child});

  final Widget child;

  /// 支持的语言，必须与主壳 `MaterialApp.supportedLocales` 一致。
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('zh', 'Hans'),
  ];

  /// 本地化 delegate 集合：**flutter 侧 + mui 侧**都要有。
  ///
  /// - flutter 侧那几项：给本层之下的 flutter widget 用（`AppBar` 等），
  ///   与主壳 `MaterialApp.localizationsDelegates` 保持一致
  /// - `mui.GlobalMaterialLocalizations.delegate`：给 mui 侧 widget 用
  ///   （smart_dialog 5.3 的 dialog 必需）
  ///
  /// 两套 `MaterialLocalizations` 是不同类，可以同时挂在同一棵树上。
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    f.DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
    mui.GlobalMaterialLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    // 用 MediaQuery 的 platformBrightness，避免依赖任一库的 Theme。
    final isDark =
        f.MediaQuery.platformBrightnessOf(context) == f.Brightness.dark;

    return mui.Theme(
      data: isDark ? Themes.muiDark : Themes.muiLight,
      child: Localizations(
        // `Localizations` 是 flutter/widgets 的（material_ui 只是 re-export，
        // 它没有自己的 Localizations），且**没有** `supportedLocales` 参数 ——
        // locale 由下面的 localeOf 给定。
        locale: Localizations.localeOf(context),
        delegates: localizationsDelegates,
        child: child,
      ),
    );
  }
}
