import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:flex_color_scheme/flex_color_scheme.dart';

/// 主题。
///
/// ## 为什么这里有两套主题
///
/// `flutter/material.dart` 与 `material_ui/material_ui.dart` 是**两套完全独立**的
/// Material 实现：`flutter/material.dart` 不 re-export `material_ui`，两边各有自己的
/// `ThemeData` / `ColorScheme`（同名不同类），且彼此的 `Theme.of()` 找不到对方时
/// **不报错，而是静默返回 `ThemeData.fallback()`**（实测：跨库读到的 primary 是
/// 默认紫色，不是我们的品牌色）。
///
/// 本项目只有 5 个包已迁 material_ui（flex_color_scheme 9 / flutter_smart_dialog 5 /
/// cached_network_image 4 / dynamic_color 2 / animations 3），其余约 50 个直接依赖
/// （media_kit / adaptive_dialog / infinite_scroll_pagination / syncfusion /
/// photo_view / kedo…）仍用 `flutter/material.dart`。所以不能「全库换 import」——
/// 那会让那 50 个包全部落进 fallback 主题。做法是**同时提供两套**：
///
///   - [light] / [dark]：**flutter 版**，给主壳（`MaterialApp`）与绝大多数页面用
///   - [muiLight] / [muiDark]：**material_ui 版**，由 `<ThemeBridge>` 挂在
///     `MaterialApp.builder` 上，供已迁 material_ui 的包使用
///
/// 两套都源自同一份 FlexColorScheme 配色（同一 `scheme` / `primary` / `secondary`），
/// 所以视觉一致。flex9 只支持 material_ui 侧（全库无 `flutter/material.dart` 的
/// import），故 flutter 版由 material_ui 版**转换**而来（见 [_toFlutter]）。
class Themes {
  Themes._();

  /// 品牌主色（原 flex8 版本用的就是这两个色）
  static const Color brand = Color(0xFF7778dc);
  static const Color brandSecondary = Color(0xFF81aad3);

  static final FlexScheme _scheme = FlexScheme.flutterDash;

  // ---------------------------------------------------------------- material_ui 侧
  //
  // flex_color_scheme 9 的 FlexThemeData 返回的就是 material_ui 版的 ThemeData
  // （其 flex_theme_data_extensions.dart 只 import material_ui + cupertino_ui）。

  static final mui.ThemeData muiLight = FlexThemeData.light(
    scheme: _scheme,
    primary: brand,
    secondary: brandSecondary,
  ).copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );

  static final mui.ThemeData muiDark = FlexThemeData.dark(
    scheme: _scheme,
    primary: brand,
    secondary: brandSecondary,
    // 暗色主题里 primary/secondary 只作 seed，需要显式告诉 flex「亮色用的是哪个色」
    // 才能正确算出 fixed 系列。不设会有 FlexColorScheme WARNING
    // （primaryLightRef/secondaryLightRef is null）。
    primaryLightRef: brand,
    secondaryLightRef: brandSecondary,
  ).copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );

  // ---------------------------------------------------------------- flutter 侧

  /// 主壳主题。由 material_ui 版转换而来，保证两套配色一致。
  static final ThemeData light = _toFlutter(muiLight);
  static final ThemeData dark = _toFlutter(muiDark);

  /// 把 material_ui 的 ThemeData 转成 flutter 的 ThemeData。
  ///
  /// 只搬本项目实际会读到的字段（实测 `Get.theme.*` 的用法：`primaryColor` 39 处、
  /// `scaffoldBackgroundColor` 6 处、`dividerColor` / `textTheme` / `colorScheme`
  /// 各 1 处），其余交给 M3 默认值。`Color` 是两边共享的同一个类
  /// （`dart:ui`），所以颜色可以直接过桥。
  static ThemeData _toFlutter(mui.ThemeData src) {
    final s = src.colorScheme;
    return ThemeData(
      brightness: src.brightness,
      useMaterial3: src.useMaterial3,
      // fromSeed + 显式覆盖：既拿到完整的 M3 派生色（onXxx / container 等），
      // 又钉住 flex9 算出来的主色，避免两套主题主色不一致。
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: src.brightness,
        primary: Color(s.primary.toARGB32()),
        onPrimary: Color(s.onPrimary.toARGB32()),
        secondary: Color(s.secondary.toARGB32()),
        onSecondary: Color(s.onSecondary.toARGB32()),
        surface: Color(s.surface.toARGB32()),
        onSurface: Color(s.onSurface.toARGB32()),
        error: Color(s.error.toARGB32()),
      ),
      scaffoldBackgroundColor: Color(src.scaffoldBackgroundColor.toARGB32()),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
