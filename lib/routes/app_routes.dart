part of 'app_pages.dart';

abstract class Routes {
  Routes._();

  // notfound
  static const notfound = _Paths.notfound;

  static const splash = _Paths.splash;
  static const homepage = _Paths.homepage;
  static const detail = _Paths.detail;
  static const search = _Paths.search;
  static const directory = _Paths.directory;
  static const document = _Paths.document;
  static const file = _Paths.file;
  static const imagePreview = _Paths.imagePreview;
  static const videoPlayer = _Paths.videoPlayer;
  static const audioPlayer = _Paths.audioPlayer;

  // Settings
  static const setting = _Paths.setting;
  static const settingServer = _Paths.setting + _Paths.server;
  static const settingDownload = _Paths.setting + _Paths.download;
  static const settingAbout = _Paths.setting + _Paths.about;
  static const settingRecent = _Paths.setting + _Paths.recent;
  static const settingFavorite = _Paths.setting + _Paths.favorite;
  static const settingPreviewImage = _Paths.setting + _Paths.previewImage;
  static const settingPreviewAudio = _Paths.setting + _Paths.previewAudio;
  static const settingPreviewVideo = _Paths.setting + _Paths.previewVideo;
  static const settingPreviewDocument = _Paths.setting + _Paths.previewDocument;
}

abstract class _Paths {
  static const splash = '/';
  static const notfound = '/notfound';
  static const homepage = '/homepage';
  static const detail = '/detail';
  static const search = '/search';
  static const directory = '/directory';
  static const document = '/document';
  static const file = '/file';
  static const imagePreview = '/image/preview';
  static const videoPlayer = '/video/player';
  static const audioPlayer = '/audio/player';

  // Settings
  static const setting = '/setting';
  static const server = '/server';
  static const download = '/download';
  static const about = '/about';
  static const recent = '/recent';
  static const favorite = '/favorite';
  static const previewImage = '/preview/image';
  static const previewAudio = '/preview/audio';
  static const previewVideo = '/preview/video';
  static const previewDocument = '/preview/document';
}
