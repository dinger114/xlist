import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:xlist/helper/index.dart';

/// 页面来源
class PageSource {
  static const homepage = 'homepage';
  static const detail = 'detail';
  static const directory = 'directory';
}

/// 服务器类型
class ServerType {
  static const alist = 0;
  static const ftp = 1;
  static const sftp = 2;
  static const smb = 3;
}

/// 排序类型
class SortType {
  static const timeDesc = 0;
  static const timeAsc = 1;
  static const nameDesc = 2;
  static const nameAsc = 3;
  static const sizeDesc = 4;
  static const sizeAsc = 5;
}

/// 播放模式
class PlayMode {
  static const listLoop = 0;
  static const singleLoop = 1;
  static const playPause = 2;
  static const shuffle = 3;

  static const playModeIcons = {
    PlayMode.listLoop: CupertinoIcons.repeat,
    PlayMode.singleLoop: CupertinoIcons.repeat_1,
    PlayMode.playPause: CupertinoIcons.stop_circle,
    PlayMode.shuffle: CupertinoIcons.shuffle,
  };

  static IconData? getIcon(int mode) {
    return playModeIcons[mode];
  }
}

/// 布局方式
class LayoutType {
  static const unknown = 0;
  static const list = 1;
  static const grid = 2;
}

/// 文件类型
class FileType {
  static const unknown = 0;
  static const folder = 1;
  static const video = 2;
  static const audio = 3;
  static const text = 4;
  static const image = 5;

  /// 获取文件类型图标
  /// [type] 文件类型
  static IconData getIcon(int type, String name) {
    if (type == FileType.folder) return FontAwesomeIcons.solidFolder.data;
    if (PreviewHelper.isImage(name)) {
      return FontAwesomeIcons.solidFileImage.data;
    }
    if (PreviewHelper.isVideo(name)) {
      return FontAwesomeIcons.solidFileVideo.data;
    }
    if (PreviewHelper.isAudio(name)) {
      return FontAwesomeIcons.solidFileAudio.data;
    }
    if (PreviewHelper.isDocument(name)) {
      return FontAwesomeIcons.solidFileLines.data;
    }

    return fileTypeIcons[type];
  }
}

/// 文件类型图标
final fileTypeIcons = [
  FontAwesomeIcons.solidFile.data,
  FontAwesomeIcons.solidFolder.data,
  FontAwesomeIcons.solidFileVideo.data,
  FontAwesomeIcons.solidFileAudio.data,
  FontAwesomeIcons.solidFileLines.data,
  FontAwesomeIcons.solidFileImage.data,
];

const themeModeMap = {
  'system': ThemeMode.system,
  'light': ThemeMode.light,
  'dark': ThemeMode.dark,
};

const themeModeTextMap = {'system': '跟随系统', 'light': '明亮', 'dark': '深邃'};

class Provider {
  static const String aliyunDrive = 'Aliyundrive';
  static const String baidu = 'Baidu';
  static const String cloud115 = '115';
}

class IjkPlayerTrackType {
  static const int video = 1;
  static const int audio = 2;
  static const int timedtext = 3;
}
