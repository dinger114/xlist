import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/constants/preview.dart';
import 'package:xlist/helper/preview_helper.dart';

/// md 分支判定的回归测试。
///
/// 背景：`.md` 曾走「代码高亮」分支，显示的是源码而非渲染后的文档。
/// 修好后有个**顺序不变量**必须守住：`md` 同时命中 `isCode()`（它在
/// `kSupportPreviewCodeTypes` 里）与 `isMarkdown()`，所以渲染时必须优先
/// 走 markdown。有人调换 `document/view.dart` 里两个 if 的顺序就会静默回归。
///
/// `isMarkdown` 刻意不查 `PreferencesStorage`，因此可直接单测（无需 DI 桩）。
void main() {
  group('PreviewHelper.isMarkdown', () {
    test('识别 .md（大小写不敏感）', () {
      expect(PreviewHelper.isMarkdown('README.md'), isTrue);
      expect(PreviewHelper.isMarkdown('notes.MD'), isTrue);
      expect(PreviewHelper.isMarkdown('a/b/c/doc.Md'), isTrue);
    });

    test('不误判其它类型', () {
      for (final n in [
        'a.txt',
        'a.markdown',
        'a.mdx',
        'a.dart',
        'a.html',
        'md'
      ]) {
        expect(PreviewHelper.isMarkdown(n), isFalse, reason: n);
      }
    });

    test('md 确实也在代码类型表里 —— 这正是需要优先判断的原因', () {
      // 若这条断言失败，说明 md 被移出了代码类型表，
      // document/view.dart 里的顺序依赖就可以去掉了。
      expect(kSupportPreviewCodeTypes.contains('md'), isTrue);
      expect(kCodeLanguages['md'], 'markdown');
    });

    test('md 的语言名只是高亮语法名，不代表有渲染器', () {
      // 记录一个易混点：'markdown' 是 highlight.js 的语法标识，
      // 不是 markdown 渲染。历史上就是被这个字面值误导的。
      expect(kCodeLanguages.containsKey('md'), isTrue);
      // 代码类型表里除 md 外，其余都不应被 markdown 分支截走
      final markdownish = kSupportPreviewCodeTypes
          .where((e) => e != 'md')
          .where((e) => PreviewHelper.isMarkdown('x.$e'))
          .toList();
      expect(markdownish, isEmpty);
    });
  });
}
