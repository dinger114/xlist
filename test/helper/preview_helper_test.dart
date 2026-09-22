import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:xlist/constants/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/storages/index.dart';

import '../support/storage_harness.dart';

/// `PreviewHelper` 的类型判定测试。
///
/// 这些方法决定「点条目是直接播放 / 预览，还是转成下载」，被 homepage、
/// detail、directory、file 等页面的点击逻辑共用，此前无覆盖。
///
/// 存储说明：类型表存在 `PreferencesStorage`（get_storage）。这里用
/// `setUpTestStorage` 打桩 path_provider 后**真实**初始化 GetStorage，
/// 所以「用户自定义类型表」这类用例的读写是落盘的，不是内存假象。
///
/// 已知覆盖缺口：`isDocument` 里 `GetPlatform.isAndroid` 的分支取宿主 OS
/// （单元测试跑在 macOS 上，恒为非 Android），所以 Android 专属的
/// 「只支持代码 + pdf」逻辑**无法**在此测到，只能真机验证。
void main() {
  setUpAll(setUpTestStorage);
  tearDownAll(tearDownTestStorage);

  setUp(() {
    Get.reset();
    putPreferences();
  });

  tearDown(Get.reset);

  group('isImage', () {
    test('默认类型表内的图片扩展名识别为图片', () {
      for (final name in ['a.jpg', 'a.jpeg', 'a.png', 'a.gif', 'a.webp']) {
        expect(PreviewHelper.isImage(name), isTrue, reason: '$name 应为图片');
      }
    });

    test('大小写不敏感', () {
      expect(PreviewHelper.isImage('A.JPG'), isTrue);
      expect(PreviewHelper.isImage('A.PnG'), isTrue);
    });

    test('非图片扩展名返回 false', () {
      expect(PreviewHelper.isImage('a.mp4'), isFalse);
      expect(PreviewHelper.isImage('a.txt'), isFalse);
    });

    test('无扩展名返回 false', () {
      expect(PreviewHelper.isImage('README'), isFalse);
    });

    test('路径中含目录时只看最后一段的扩展名', () {
      expect(PreviewHelper.isImage('/a/b.jpg/c.mp4'), isFalse);
      expect(PreviewHelper.isImage('/a/b.mp4/c.jpg'), isTrue);
    });

    test('用户自定义类型表生效：从表里删掉的扩展名不再识别为图片', () {
      final prefs = Get.find<PreferencesStorage>();
      expect(PreviewHelper.isImage('a.webp'), isTrue, reason: '前置：默认识别 webp');

      prefs.imageSupportTypes.val = ['jpg', 'png'];
      expect(PreviewHelper.isImage('a.webp'), isFalse, reason: '删掉后应不再识别');
      expect(PreviewHelper.isImage('a.jpg'), isTrue);
    });
  });

  group('isVideo', () {
    test('默认类型表内的视频扩展名识别为视频', () {
      for (final name in ['a.mp4', 'a.mkv', 'a.avi', 'a.mov']) {
        expect(PreviewHelper.isVideo(name), isTrue, reason: '$name 应为视频');
      }
    });

    test('.strm 硬编码为视频：即使用户从偏好里删掉 strm 也仍识别', () {
      final prefs = Get.find<PreferencesStorage>();

      // 默认表含 strm（见 constants/preview.dart），所以先把用户偏好里的 strm
      // 去掉，否则测到的只是「表里有 strm」而不是硬编码分支
      final list = prefs.videoSupportTypes.val
          .where((e) => e.toString() != 'strm')
          .toList();
      prefs.videoSupportTypes.val = list;
      expect(prefs.videoSupportTypes.val.contains('strm'), isFalse,
          reason: '前置条件：此时偏好里已无 strm');

      // 硬编码分支仍返回 true
      expect(PreviewHelper.isVideo('a.strm'), isTrue);
      expect(PreviewHelper.isVideo('A.STRM'), isTrue, reason: '应大小写不敏感');
    });

    test('非视频扩展名返回 false', () {
      expect(PreviewHelper.isVideo('a.jpg'), isFalse);
      expect(PreviewHelper.isVideo('a.txt'), isFalse);
    });

    test('音频扩展名不算视频（isVideo 与 isAudio 不交叉）', () {
      expect(PreviewHelper.isVideo('a.mp3'), isFalse);
    });

    test('用户自定义类型表生效：从表里删掉的扩展名不再识别为视频', () {
      final prefs = Get.find<PreferencesStorage>();
      expect(PreviewHelper.isVideo('a.mkv'), isTrue, reason: '前置：默认识别 mkv');

      prefs.videoSupportTypes.val = ['mp4'];
      expect(PreviewHelper.isVideo('a.mkv'), isFalse, reason: '删掉后应不再识别');
      expect(PreviewHelper.isVideo('a.mp4'), isTrue);
    });
  });

  group('isAudio', () {
    test('默认类型表内的音频扩展名识别为音频', () {
      for (final name in ['a.mp3', 'a.flac', 'a.wav', 'a.m4a']) {
        expect(PreviewHelper.isAudio(name), isTrue, reason: '$name 应为音频');
      }
    });

    test('非音频扩展名返回 false', () {
      expect(PreviewHelper.isAudio('a.mp4'), isFalse);
      expect(PreviewHelper.isAudio('a.jpg'), isFalse);
    });

    test('无扩展名返回 false', () {
      expect(PreviewHelper.isAudio('README'), isFalse);
    });

    test('用户自定义类型表生效', () {
      final prefs = Get.find<PreferencesStorage>();
      prefs.audioSupportTypes.val = ['mp3'];
      expect(PreviewHelper.isAudio('a.flac'), isFalse);
      expect(PreviewHelper.isAudio('a.mp3'), isTrue);
    });
  });

  group('isHtml', () {
    test('html 与 htm 都识别为 HTML', () {
      expect(PreviewHelper.isHtml('a.html'), isTrue);
      expect(PreviewHelper.isHtml('a.htm'), isTrue);
    });

    test('大小写不敏感', () {
      expect(PreviewHelper.isHtml('a.HTML'), isTrue);
    });

    test('不依赖偏好设置（纯扩展名判断）', () {
      Get.reset(); // 清掉 DI，仍应正常工作
      expect(PreviewHelper.isHtml('a.html'), isTrue);
      expect(PreviewHelper.isHtml('a.txt'), isFalse);
    });

    test('其它扩展名返回 false', () {
      expect(PreviewHelper.isHtml('a.txt'), isFalse);
      expect(PreviewHelper.isHtml('a.php'), isFalse);
    });
  });

  group('isCode', () {
    test('文档类型表与代码类型表的交集内的扩展名识别为代码', () {
      final prefs = Get.find<PreferencesStorage>();
      final intersection = prefs.documentSupportTypes.val
          .toSet()
          .intersection(kSupportPreviewCodeTypes.toSet());
      expect(intersection, isNotEmpty, reason: '交集不应为空，否则 Android 上永远无法预览代码');

      for (final ext in intersection) {
        expect(PreviewHelper.isCode('a.$ext'), isTrue,
            reason: '交集内的 $ext 应识别为代码');
      }
    });

    test('不在交集中的扩展名返回 false', () {
      expect(PreviewHelper.isCode('a.xyz'), isFalse);
    });

    test('代码判定是交集的子集：文档类型但不属于代码表的不算代码', () {
      expect(PreviewHelper.isDocument('a.pdf'), isTrue);
      expect(PreviewHelper.isCode('a.pdf'), isFalse);
      expect(kSupportPreviewCodeTypes.contains('pdf'), isFalse);
    });
  });

  group('isDocument', () {
    test('pdf 是所有平台的文档预览类型', () {
      expect(PreviewHelper.isDocument('a.pdf'), isTrue);
    });

    test('非文档扩展名返回 false', () {
      expect(PreviewHelper.isDocument('a.mp4'), isFalse);
      expect(PreviewHelper.isDocument('a.jpg'), isFalse);
    });

    test('图片不因 isImage 为真而被当成文档', () {
      expect(PreviewHelper.isImage('a.png'), isTrue);
      expect(PreviewHelper.isDocument('a.png'), isFalse);
    });
  });

  group('类型判定互斥性（同一文件不应同时命中多个播放器分支）', () {
    test('视频扩展名不被判为音频/图片/文档', () {
      expect(PreviewHelper.isVideo('a.mp4'), isTrue);
      expect(PreviewHelper.isAudio('a.mp4'), isFalse);
      expect(PreviewHelper.isImage('a.mp4'), isFalse);
      expect(PreviewHelper.isDocument('a.mp4'), isFalse);
    });

    test('音频扩展名不被判为视频/图片', () {
      expect(PreviewHelper.isAudio('a.mp3'), isTrue);
      expect(PreviewHelper.isVideo('a.mp3'), isFalse);
      expect(PreviewHelper.isImage('a.mp3'), isFalse);
    });

    test('图片扩展名不被判为视频/音频/文档', () {
      expect(PreviewHelper.isImage('a.jpg'), isTrue);
      expect(PreviewHelper.isVideo('a.jpg'), isFalse);
      expect(PreviewHelper.isAudio('a.jpg'), isFalse);
      expect(PreviewHelper.isDocument('a.jpg'), isFalse);
    });
  });
}
