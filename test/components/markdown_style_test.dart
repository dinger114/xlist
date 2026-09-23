import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:xlist/components/markdown_style.dart';

/// Markdown 排版回归测试。
///
/// 背景：md 渲染接好后用户反馈「排版乱七八糟，可读性差」。
/// 根因是 `MarkdownStyleSheet.fromTheme` 的默认值把所有 `*Padding` 都设为
/// `EdgeInsets.zero`，标题/段落/列表之间没有任何垂直间距。
///
/// 这些断言直接锁住「间距存在」这件事 —— 一旦有人换回 `fromTheme` 默认值
/// 或删掉 padding，测试立刻失败。
/// 相对亮度（WCAG 2.x）：用于验证正文与背景的对比度。
double _luminance(Color c) {
  double ch(double v) {
    v = v / 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(c.r * 255) +
      0.7152 * ch(c.g * 255) +
      0.0722 * ch(c.b * 255);
}

/// 对比度（WCAG 2.x），1:1 ~ 21:1
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final isDark in [true, false]) {
    final label = isDark ? '暗色' : '亮色';

    group('MarkdownStyles.build($label)', () {
      final s = MarkdownStyles.build(isDark: isDark);

      test('各级标题都有非零垂直间距（防「挤成一团」）', () {
        for (final entry in {
          'h1': s.h1Padding,
          'h2': s.h2Padding,
          'h3': s.h3Padding,
          'h4': s.h4Padding,
          'h5': s.h5Padding,
          'h6': s.h6Padding,
        }.entries) {
          final pad = entry.value;
          expect(pad, isNotNull, reason: '${entry.key} 缺少 padding');
          final vertical = pad!.top + pad.bottom;
          expect(vertical, greaterThan(0),
              reason: '${entry.key} 垂直间距为 0，会与相邻元素挤在一起');
        }
      });

      test('段落有下间距，块级元素之间不留空', () {
        expect(s.pPadding, isNotNull);
        expect(s.pPadding!.bottom, greaterThan(0));
      });

      test('块间距与列表缩进为正', () {
        expect(s.blockSpacing, greaterThan(0));
        expect(s.listIndent, greaterThan(0));
      });

      test('行内代码有底色（否则与正文无法区分）', () {
        expect(s.code?.backgroundColor, isNotNull);
        expect(s.code?.fontFamily, 'monospace');
      });

      test('代码块有内边距与装饰', () {
        expect(s.codeblockPadding, isNotNull);
        expect(s.codeblockDecoration, isNotNull);
      });

      test('引用块有内边距与左侧竖线装饰', () {
        expect(s.blockquotePadding, isNotNull);
        expect(s.blockquoteDecoration, isNotNull);
      });

      test('链接颜色跟随主题，不是硬编码 blue', () {
        // fromTheme 默认 a: TextStyle(color: Colors.blue) ——
        // 暗色背景 #121212 下对比度不足。
        expect(s.a?.color, isNotNull);
        expect(s.a?.color, isNot(Colors.blue));
      });

      test('正文字号足够大且是逻辑像素（真机可读性）', () {
        final size = s.p?.fontSize;
        expect(size, isNotNull);
        // 曾经传 ScreenUtil 的 scaleWidth（≈0.38）相乘 → 实际只有 ~6px。
        // 这里直接钉住下限，防止任何人再引入缩放系数。
        expect(size!, greaterThanOrEqualTo(15.0),
            reason: '正文字号 $size 过小；本项目 designSize 与设备逻辑尺寸'
                '单位不一致，不可用 .r/.sp 缩放');
        expect(size, lessThan(20.0), reason: '正文字号也不该过大');
        expect(s.p?.height, isNotNull);
        expect(s.p?.height, greaterThan(1.2));
      });

      test('标题字号严格递减且都大于正文', () {
        final body = s.p!.fontSize!;
        final heads = [
          s.h1!.fontSize!,
          s.h2!.fontSize!,
          s.h3!.fontSize!,
          s.h4!.fontSize!,
          s.h5!.fontSize!,
          s.h6!.fontSize!,
        ];
        expect(heads[0], greaterThan(body), reason: 'h1 应大于正文');
        for (var i = 1; i < heads.length; i++) {
          expect(heads[i], lessThan(heads[i - 1]), reason: 'h${i + 1} 应小于 h$i');
        }
        // 正文是逻辑像素，标题也不该被缩放成小号
        expect(heads.last, greaterThanOrEqualTo(12.0));
      });

      test('分隔线不是 5px 粗边（默认值过重）', () {
        final deco = s.horizontalRuleDecoration as BoxDecoration?;
        final side = (deco?.border as Border?)?.top;
        expect(side, isNotNull);
        expect(side!.width, lessThan(5.0));
      });

      test('表格有边框与单元格内边距', () {
        expect(s.tableBorder, isNotNull);
        expect(s.tableCellsPadding, isNotNull);
        expect(s.tableHeadCellsPadding, isNotNull);
      });

      test('正文色与页面背景的对比度足够（可读性硬指标）', () {
        final c = s.p?.color;
        expect(c, isNotNull);
        // 文档页背景是自定义色（见 CommonUtils.backgroundColor）。
        // 正文用了半透明色（white70 / black87），会与背景合成 ——
        // 直接算合成后的实际对比度，而不是断言 alpha=1.0。
        final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF2F2F7);
        final composed = Color.alphaBlend(c!, bg);
        final ratio = _contrastRatio(composed, bg);
        // WCAG AA 正文要求 4.5:1
        expect(ratio, greaterThan(4.5), reason: '正文对比度 $ratio 低于 AA 标准');
      });
    });
  }

  test('亮暗两套配色的正文色不同', () {
    final light = MarkdownStyles.build(isDark: false);
    final dark = MarkdownStyles.build(isDark: true);
    expect(light.p?.color, isNot(dark.p?.color));
    expect(light.a?.color, isNot(dark.a?.color));
  });

  testWidgets('用该样式渲染真实 Markdown 不抛异常', (tester) async {
    const md = '''
# 标题一

正文段落，含 `行内代码` 与 [链接](https://example.com)。

## 标题二

- 项目一
- 项目二

> 引用内容

```dart
void main() {}
```

| 列A | 列B |
| --- | --- |
| 1   | 2   |

---
''';
    for (final isDark in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Markdown(
            data: md,
            styleSheet: MarkdownStyles.build(isDark: isDark),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'isDark=$isDark');
    }
  });
}
