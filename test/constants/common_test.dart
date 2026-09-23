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
      expect(SortType.timeDesc, 0);
      expect(SortType.timeAsc, 1);
      expect(SortType.nameDesc, 2);
      expect(SortType.nameAsc, 3);
      expect(SortType.sizeDesc, 4);
      expect(SortType.sizeAsc, 5);
    });

    test('FileType（存进 recent / favorite 表）', () {
      expect(FileType.unknown, 0);
      expect(FileType.folder, 1);
      expect(FileType.video, 2);
      expect(FileType.audio, 3);
      expect(FileType.text, 4);
      expect(FileType.image, 5);
    });

    test('PlayMode（存进偏好设置）', () {
      expect(PlayMode.listLoop, 0);
      expect(PlayMode.singleLoop, 1);
      expect(PlayMode.playPause, 2);
      expect(PlayMode.shuffle, 3);
    });

    test('LayoutType（存进偏好设置）', () {
      expect(LayoutType.unknown, 0);
      expect(LayoutType.list, 1);
      expect(LayoutType.grid, 2);
    });

    test('ServerType（存进 server 表）', () {
      expect(ServerType.alist, 0);
      expect(ServerType.ftp, 1);
      expect(ServerType.sftp, 2);
      expect(ServerType.smb, 3);
    });
  });

  group('PlayMode.getIcon', () {
    test('四个模式都能取到图标', () {
      for (final mode in [
        PlayMode.listLoop,
        PlayMode.singleLoop,
        PlayMode.playPause,
        PlayMode.shuffle,
      ]) {
        expect(PlayMode.getIcon(mode), isNotNull, reason: '模式 $mode 缺少图标');
      }
    });

    test('未知模式返回 null（不抛异常）', () {
      expect(PlayMode.getIcon(999), isNull);
    });
  });

  group('fileTypeIcons 表', () {
    test('长度覆盖所有 FileType 取值', () {
      // FileType 最大值为 IMAGE = 5，表至少有 6 项才能被下标命中
      expect(fileTypeIcons.length, greaterThanOrEqualTo(6));
    });

    test('下标与 FileType 常量对齐（不会越界）', () {
      // 表是位置数组，顺序必须与 FileType 一致；这里只锁「下标可达」，
      // 具体图标语义靠人工 review
      expect(fileTypeIcons[FileType.unknown], isNotNull);
      expect(fileTypeIcons[FileType.folder], isNotNull);
      expect(fileTypeIcons[FileType.video], isNotNull);
      expect(fileTypeIcons[FileType.audio], isNotNull);
      expect(fileTypeIcons[FileType.text], isNotNull);
      expect(fileTypeIcons[FileType.image], isNotNull);
    });
  });

  group('ThemeModeMap', () {
    test('三个 key 与 ThemeMode 对应', () {
      expect(themeModeMap['system'], ThemeMode.system);
      expect(themeModeMap['light'], ThemeMode.light);
      expect(themeModeMap['dark'], ThemeMode.dark);
    });

    test('覆盖 CommonStorage 里 themeMode 的所有合法取值', () {
      // 默认值是 'system'，设置页只会写这三个
      for (final key in ['system', 'light', 'dark']) {
        expect(themeModeMap[key], isNotNull, reason: '$key 未映射，会导致 ! 断言崩溃');
      }
    });
  });

  group('Routes 常量', () {
    test('初始路由为 splash（根路径）', () {
      expect(Routes.splash, '/');
    });

    test('顶层页面路径都在根下', () {
      expect(Routes.homepage, '/homepage');
      expect(Routes.detail, '/detail');
      expect(Routes.search, '/search');
      expect(Routes.directory, '/directory');
      expect(Routes.document, '/document');
      expect(Routes.file, '/file');
      expect(Routes.videoPlayer, '/video/player');
      expect(Routes.audioPlayer, '/audio/player');
    });

    test('设置页子路由由 SETTING + 子路径拼接而成', () {
      expect(Routes.setting, '/setting');
      expect(Routes.settingServer, '/setting/server');
      expect(Routes.settingDownload, '/setting/download');
      expect(Routes.settingAbout, '/setting/about');
      expect(Routes.settingRecent, '/setting/recent');
      expect(Routes.settingFavorite, '/setting/favorite');
      expect(Routes.settingPreviewImage, '/setting/preview/image');
      expect(Routes.settingPreviewAudio, '/setting/preview/audio');
      expect(Routes.settingPreviewVideo, '/setting/preview/video');
    });

    test('所有路由路径互不重复', () {
      final paths = [
        Routes.splash,
        Routes.notfound,
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
      ];
      expect(paths.toSet().length, paths.length, reason: '存在重复路由路径');
    });

    test('设置页子路由路径以父路径为前缀（GetX children 寻址依赖这点）', () {
      final children = [
        Routes.settingServer,
        Routes.settingDownload,
        Routes.settingAbout,
        Routes.settingRecent,
        Routes.settingFavorite,
        Routes.settingPreviewImage,
        Routes.settingPreviewAudio,
        Routes.settingPreviewVideo,
      ];
      for (final c in children) {
        expect(c.startsWith(Routes.setting), isTrue,
            reason: '$c 未以 ${Routes.setting} 开头');
        expect(c, isNot(Routes.setting), reason: '$c 与父路径重复');
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
