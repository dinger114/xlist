import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/constants/index.dart';
import 'package:xlist/routes/app_pages.dart';

/// 常量表的回归锁。
///
/// 这些数字会被写进本地数据库与偏好设置（如 `sortType`、`playMode`、
/// `FileType` 存进 recent/favorite 表），**改动数值会让老用户的已有数据失配**
/// （例如旧记录 type=2 是视频，若把 VIDEO 改成 3，旧记录会被当成音频）。
/// 所以这里锁死数值，任何改动都必须是有意为之并配套数据迁移。
///
/// 路由路径同样锁死：它同时被本地存储（设置页的「启动页」类偏好）与
/// 导航调用使用，且 Phase 1 迁 go_router 时要以这张表为对照。
void main() {
  group('枚举常量值稳定（改动会导致老数据失配）', () {
    test('SortType', () {
      expect(SortType.TIME_DESC, 0);
      expect(SortType.TIME_ASC, 1);
      expect(SortType.NAME_DESC, 2);
      expect(SortType.NAME_ASC, 3);
      expect(SortType.SIZE_DESC, 4);
      expect(SortType.SIZE_ASC, 5);
    });

    test('FileType（存进 recent / favorite 表）', () {
      expect(FileType.UNKNOWN, 0);
      expect(FileType.FOLDER, 1);
      expect(FileType.VIDEO, 2);
      expect(FileType.AUDIO, 3);
      expect(FileType.TEXT, 4);
      expect(FileType.IMAGE, 5);
    });

    test('PlayMode（存进偏好设置）', () {
      expect(PlayMode.LIST_LOOP, 0);
      expect(PlayMode.SINGLE_LOOP, 1);
      expect(PlayMode.PLAY_PAUSE, 2);
      expect(PlayMode.SHUFFLE, 3);
    });

    test('LayoutType（存进偏好设置）', () {
      expect(LayoutType.UNKNOWN, 0);
      expect(LayoutType.LIST, 1);
      expect(LayoutType.GRID, 2);
    });

    test('ServerType（存进 server 表）', () {
      expect(ServerType.ALIST, 0);
      expect(ServerType.FTP, 1);
      expect(ServerType.SFTP, 2);
      expect(ServerType.SMB, 3);
    });
  });

  group('PlayMode.getIcon', () {
    test('四个模式都能取到图标', () {
      for (final mode in [
        PlayMode.LIST_LOOP,
        PlayMode.SINGLE_LOOP,
        PlayMode.PLAY_PAUSE,
        PlayMode.SHUFFLE,
      ]) {
        expect(PlayMode.getIcon(mode), isNotNull, reason: '模式 $mode 缺少图标');
      }
    });

    test('未知模式返回 null（不抛异常）', () {
      expect(PlayMode.getIcon(999), isNull);
    });
  });

  group('FileTypeIcons 表', () {
    test('长度覆盖所有 FileType 取值', () {
      // FileType 最大值为 IMAGE = 5，表至少有 6 项才能被下标命中
      expect(FileTypeIcons.length, greaterThanOrEqualTo(6));
    });

    test('下标与 FileType 常量对齐（不会越界）', () {
      // 表是位置数组，顺序必须与 FileType 一致；这里只锁「下标可达」，
      // 具体图标语义靠人工 review
      expect(FileTypeIcons[FileType.UNKNOWN], isNotNull);
      expect(FileTypeIcons[FileType.FOLDER], isNotNull);
      expect(FileTypeIcons[FileType.VIDEO], isNotNull);
      expect(FileTypeIcons[FileType.AUDIO], isNotNull);
      expect(FileTypeIcons[FileType.TEXT], isNotNull);
      expect(FileTypeIcons[FileType.IMAGE], isNotNull);
    });
  });

  group('ThemeModeMap', () {
    test('三个 key 与 ThemeMode 对应', () {
      expect(ThemeModeMap['system'], ThemeMode.system);
      expect(ThemeModeMap['light'], ThemeMode.light);
      expect(ThemeModeMap['dark'], ThemeMode.dark);
    });

    test('覆盖 CommonStorage 里 themeMode 的所有合法取值', () {
      // 默认值是 'system'，设置页只会写这三个
      for (final key in ['system', 'light', 'dark']) {
        expect(ThemeModeMap[key], isNotNull, reason: '$key 未映射，会导致 ! 断言崩溃');
      }
    });
  });

  group('Routes 常量', () {
    test('初始路由为 splash（根路径）', () {
      expect(Routes.SPLASH, '/');
    });

    test('顶层页面路径都在根下', () {
      expect(Routes.HOMEPAGE, '/homepage');
      expect(Routes.DETAIL, '/detail');
      expect(Routes.SEARCH, '/search');
      expect(Routes.DIRECTORY, '/directory');
      expect(Routes.DOCUMENT, '/document');
      expect(Routes.FILE, '/file');
      expect(Routes.VIDEO_PLAYER, '/video/player');
      expect(Routes.AUDIO_PLAYER, '/audio/player');
    });

    test('设置页子路由由 SETTING + 子路径拼接而成', () {
      expect(Routes.SETTING, '/setting');
      expect(Routes.SETTING_SERVER, '/setting/server');
      expect(Routes.SETTING_DOWNLOAD, '/setting/download');
      expect(Routes.SETTING_ABOUT, '/setting/about');
      expect(Routes.SETTING_RECENT, '/setting/recent');
      expect(Routes.SETTING_FAVORITE, '/setting/favorite');
      expect(Routes.SETTING_PREVIEW_IMAGE, '/setting/preview/image');
      expect(Routes.SETTING_PREVIEW_AUDIO, '/setting/preview/audio');
      expect(Routes.SETTING_PREVIEW_VIDEO, '/setting/preview/video');
    });

    test('所有路由路径互不重复', () {
      final paths = [
        Routes.SPLASH,
        Routes.NOTFOUND,
        Routes.HOMEPAGE,
        Routes.DETAIL,
        Routes.SEARCH,
        Routes.DIRECTORY,
        Routes.DOCUMENT,
        Routes.FILE,
        Routes.IMAGE_PREVIEW,
        Routes.VIDEO_PLAYER,
        Routes.AUDIO_PLAYER,
        Routes.SETTING,
        Routes.SETTING_SERVER,
        Routes.SETTING_DOWNLOAD,
        Routes.SETTING_ABOUT,
        Routes.SETTING_RECENT,
        Routes.SETTING_FAVORITE,
        Routes.SETTING_PREVIEW_IMAGE,
        Routes.SETTING_PREVIEW_AUDIO,
        Routes.SETTING_PREVIEW_VIDEO,
      ];
      expect(paths.toSet().length, paths.length, reason: '存在重复路由路径');
    });

    test('设置页子路由路径以父路径为前缀（GetX children 寻址依赖这点）', () {
      final children = [
        Routes.SETTING_SERVER,
        Routes.SETTING_DOWNLOAD,
        Routes.SETTING_ABOUT,
        Routes.SETTING_RECENT,
        Routes.SETTING_FAVORITE,
        Routes.SETTING_PREVIEW_IMAGE,
        Routes.SETTING_PREVIEW_AUDIO,
        Routes.SETTING_PREVIEW_VIDEO,
      ];
      for (final c in children) {
        expect(c.startsWith(Routes.SETTING), isTrue,
            reason: '$c 未以 ${Routes.SETTING} 开头');
        expect(c, isNot(Routes.SETTING), reason: '$c 与父路径重复');
      }
    });
  });

  group('预览类型表', () {
    test('四类预览类型表都非空', () {
      expect(kSupportPreviewImageTypes, isNotEmpty);
      expect(kSupportPreviewVideoTypes, isNotEmpty);
      expect(kSupportPreviewAudioTypes, isNotEmpty);
      expect(kSupportPreviewDocumentTypes, isNotEmpty);
    });

    test('扩展名统一为小写、且不带点号（helper 用 replaceAll(".", "") 比对）', () {
      final all = [
        ...kSupportPreviewImageTypes,
        ...kSupportPreviewVideoTypes,
        ...kSupportPreviewAudioTypes,
        ...kSupportPreviewDocumentTypes,
      ];
      for (final e in all) {
        final ext = e.toString();
        expect(ext, ext.toLowerCase(), reason: '$ext 含大写字母，会导致匹配失败');
        expect(ext.startsWith('.'), isFalse, reason: '$ext 带点号，会导致匹配失败');
      }
    });

    test('strm 在默认视频类型表内', () {
      expect(kSupportPreviewVideoTypes.contains('strm'), isTrue);
    });
  });
}
