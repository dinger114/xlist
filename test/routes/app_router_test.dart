import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/routes/app_router.dart';

/// `AppRouter` 的扁平化与解析测试。
///
/// 这里锁住的是「路由路径与迁移前逐字相同」这条硬要求 —— 路径错了会表现为
/// 某些页面点进去空白或走 unknownRoute，而那种问题在真机上很难与别的故障区分。
void main() {
  group('路由扁平化', () {
    test('子路由路径 = 父路径 + 子路径（与 Routes 常量一致）', () {
      final paths = AppRouter.allPaths;

      // 父
      expect(paths, contains('/setting'));
      // 子（GetX children 语义是字符串拼接）
      expect(paths, contains('/setting/server'));
      expect(paths, contains('/setting/download'));
      expect(paths, contains('/setting/about'));
      expect(paths, contains('/setting/recent'));
      expect(paths, contains('/setting/favorite'));
      expect(paths, contains('/setting/preview/image'));
      expect(paths, contains('/setting/preview/audio'));
      expect(paths, contains('/setting/preview/video'));
      expect(paths, contains('/setting/preview/document'));
    });

    test('顶层路由路径正确', () {
      final paths = AppRouter.allPaths;
      expect(
          paths,
          containsAll([
            '/',
            '/homepage',
            '/detail',
            '/search',
            '/directory',
            '/document',
            '/file',
            '/image/preview',
            '/video/player',
            '/audio/player',
          ]));
    });

    test('unknownRoute 不出现在可解析路由表里（由 onUnknownRoute 处理）', () {
      expect(AppRouter.allPaths.contains('/notfound'), isFalse);
    });

    test('路由路径无重复', () {
      final paths = AppRouter.allPaths;
      expect(paths.toSet().length, paths.length, reason: '扁平化后出现重复路径');
    });

    test('扁平化后的路径与 Routes 常量完全对得上', () {
      final paths = AppRouter.allPaths.toSet();
      // 逐个核对：这些是代码里 Get.toNamed 实际会用到的路径
      for (final p in [
        Routes.homepage,
        Routes.detail,
        Routes.search,
        Routes.directory,
        Routes.document,
        Routes.file,
        Routes.imagePreview,
        Routes.videoPlayer,
        Routes.audioPlayer,
        Routes.setting,
        Routes.settingServer,
        Routes.settingDownload,
        Routes.settingAbout,
        Routes.settingRecent,
        Routes.settingFavorite,
        Routes.settingPreviewImage,
        Routes.settingPreviewAudio,
        Routes.settingPreviewVideo,
        Routes.settingPreviewDocument,
      ]) {
        expect(paths.contains(p), isTrue, reason: '路由表缺少 $p，导航会走到 notfound');
      }
    });
  });

  group('路由解析', () {
    test('已知路径能解析到 GetPage，且带 binding', () {
      final page = AppRouter.resolve(Routes.homepage);
      expect(page, isNotNull);
      expect(page!.name, Routes.homepage);
      expect(page.binding, isNotNull, reason: '首页缺少 binding，控制器不会被创建');
    });

    test('带权限中间件的路由仍然挂着中间件（登录守卫不能丢）', () {
      final page = AppRouter.resolve(Routes.detail);
      expect(page, isNotNull);
      expect(page!.middlewares, isNotNull);
      expect(page.middlewares!.isNotEmpty, isTrue,
          reason: '详情页的 AuthMiddleware 丢失 —— 未登录也能进');
    });

    test('设置页 9 个子路由都能解析到', () {
      for (final p in [
        Routes.settingServer,
        Routes.settingDownload,
        Routes.settingAbout,
        Routes.settingRecent,
        Routes.settingFavorite,
        Routes.settingPreviewImage,
        Routes.settingPreviewAudio,
        Routes.settingPreviewVideo,
        Routes.settingPreviewDocument,
      ]) {
        expect(AppRouter.resolve(p), isNotNull, reason: '$p 无法解析');
      }
    });

    test('未知路径解析为 null（交给 onUnknownRoute）', () {
      expect(AppRouter.resolve('/不存在的路径'), isNull);
      expect(AppRouter.resolve('/setting/不存在'), isNull);
    });

    test('null 路径解析为 null，不抛异常', () {
      expect(AppRouter.resolve(null), isNull);
    });

    test('不会把父路径当成子路径（前缀匹配不算命中）', () {
      // /setting 存在，但 /settingX 不存在；不能因为都以 /setting 开头就命中
      expect(AppRouter.resolve('/settingX'), isNull);
    });
  });
}
