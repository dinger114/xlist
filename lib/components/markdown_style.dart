import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Markdown 排版样式。
///
/// ## 为什么不用 `MarkdownStyleSheet.fromTheme` 的默认值
///
/// 实测它给出来的默认值在本项目里「可读性差」，具体原因（读源码确认）：
///
///   - **所有 `*Padding` 都是 `EdgeInsets.zero`** —— 标题/段落/列表之间完全没有
///     垂直间距，整篇挤成一坨，这是「排版乱七八糟」的主因
///   - `code` 的背景色取 `theme.cardTheme.color`，本项目主题里是 null → 行内代码
///     没有底色，和正文一个样，分不出代码
///   - `a` 硬编码 `Colors.blue` —— 暗色主题（背景 #121212）下几乎看不清
///   - `horizontalRuleDecoration` 用了 **5px** 粗的 `dividerColor` 边框，过重
///
/// 所以这里把视觉相关的项全部显式覆盖，采用贴近 GitHub 的排版比例：
/// 标题字号递减、标题上方留白大于下方、正文与块级元素之间有稳定间距。
class MarkdownStyles {
  MarkdownStyles._();

  /// 基础正文字号（**逻辑像素**，即 dp）。
  ///
  /// 刻意**不用** `.sp` / `.r`：本项目 `ScreenUtilInit(designSize: Size(1080, 1920))`
  /// 的设计尺寸与设备逻辑尺寸单位不一致（实测真机 `MediaQuery.size.width` 是
  /// 411dp，而 designSize 写 1080），导致 `scaleWidth ≈ 0.381` ——
  /// 用它相乘会把 16 号字缩成 **6.1px**（实测 `16.r = 6.095px`）。
  ///
  /// 直接给逻辑像素还有一个好处：Flutter 的 `Text` 默认会应用系统的
  /// 字体大小设置（`MediaQuery.textScaler`），**无障碍缩放自动生效**，
  /// 而 `.sp` 那套反而绕过了系统设置。
  static const double _baseSize = 16;

  /// 行内代码 / 代码块背景：亮色下用极浅灰，暗色下用极浅白
  static Color _codeBg(bool isDark) =>
      isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

  /// 分隔线、表格边框
  static Color _border(bool isDark) =>
      isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12);

  /// 次要文字（h6、列表符号等）
  static Color _muted(bool isDark) =>
      isDark ? Colors.white38 : Colors.black.withValues(alpha: 0.55);

  /// 正文色。文档页背景是自定义色（亮 #F2F2F7 / 暗 #121212），
  /// 不能沿用主题的 canvas 系文字色，否则暗色下对比度不足。
  static Color _text(bool isDark) => isDark ? Colors.white70 : Colors.black87;

  /// 标题色。比正文更亮/更黑，形成层级。
  static Color _heading(bool isDark) => isDark ? Colors.white : Colors.black87;

  /// 链接色
  static Color _link(bool isDark) =>
      isDark ? const Color(0xFF9FA8FF) : const Color(0xFF5152C4);

  /// 构建样式表。
  ///
  /// [isDark] 显式传入，而不是内部读 `Get.isDarkMode` —— 这样本函数是
  /// **纯函数**，可在单测里直接断言，不必先 pump 一个 `ScreenUtilInit`。
  ///
  /// 所有尺寸都是**逻辑像素**（dp），刻意不接受缩放系数：本项目
  /// `designSize` 与设备逻辑尺寸单位不一致，任何「按 `.r`/`.sp` 缩放」的
  /// 参数都会把排版缩到约 38%（详见 [_baseSize] 的说明）。
  static MarkdownStyleSheet build({required bool isDark}) {
    final text = _text(isDark);
    final heading = _heading(isDark);
    final muted = _muted(isDark);
    final border = _border(isDark);
    final codeBg = _codeBg(isDark);

    final base = TextStyle(fontSize: _baseSize, color: text, height: 1.5);

    /// 标题：字号递减 + 上留白大于下留白（GitHub 的节奏）
    TextStyle headingStyle(double size) => TextStyle(
      fontSize: size,
      color: heading,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    return MarkdownStyleSheet(
      // ---------------- 正文与行内元素 ----------------
      p: base,
      pPadding: EdgeInsets.only(bottom: 8),
      a: base.copyWith(
        color: _link(isDark),
        decoration: TextDecoration.underline,
      ),
      em: base.copyWith(fontStyle: FontStyle.italic),
      strong: base.copyWith(fontWeight: FontWeight.w600),
      del: base.copyWith(decoration: TextDecoration.lineThrough, color: muted),

      // 行内代码：必须有底色 + 内边距，否则和正文混在一起
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: _baseSize * 0.88,
        color: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB3261E),
        backgroundColor: codeBg,
      ),

      // ---------------- 标题 ----------------
      h1: headingStyle(26),
      h1Padding: EdgeInsets.only(top: 16, bottom: 8),
      h2: headingStyle(22),
      h2Padding: EdgeInsets.only(top: 16, bottom: 8),
      h3: headingStyle(19),
      h3Padding: EdgeInsets.only(top: 14, bottom: 6),
      h4: headingStyle(17),
      h4Padding: EdgeInsets.only(top: 12, bottom: 4),
      h5: headingStyle(16),
      h5Padding: EdgeInsets.only(top: 12, bottom: 4),
      h6: TextStyle(
        fontSize: 14,
        color: muted,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h6Padding: EdgeInsets.only(top: 12, bottom: 4),

      // ---------------- 列表 ----------------
      listIndent: 20,
      listBullet: base,
      listBulletPadding: EdgeInsets.only(right: 6),
      blockSpacing: 8,

      // ---------------- 引用块 ----------------
      blockquote: base.copyWith(color: muted),
      blockquotePadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: _link(isDark), width: 3)),
      ),

      // ---------------- 代码块 ----------------
      codeblockPadding: EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),

      // ---------------- 表格 ----------------
      tableHead: base.copyWith(fontWeight: FontWeight.w600, color: heading),
      tableBody: base,
      tableHeadAlign: TextAlign.left,
      tableBorder: TableBorder.all(color: border, width: 1),
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableHeadCellsPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      tableHeadCellsDecoration: BoxDecoration(color: codeBg),
      tableCellsDecoration: const BoxDecoration(),

      // ---------------- 其它 ----------------
      // 5px 太粗（默认值），收到 1px
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      checkbox: base.copyWith(color: _link(isDark)),
      img: base,
      textAlign: WrapAlignment.start,
    );
  }

  /// 便捷入口：按当前主题明暗取样式（读 `Get.isDarkMode`）。
  ///
  /// 注意：本文件不 import get / screenutil，参数由调用方传入 ——
  /// 这样 [build] 保持纯函数、可直接单测。
  static MarkdownStyleSheet of(BuildContext context) =>
      build(isDark: Theme.of(context).brightness == Brightness.dark);
}
