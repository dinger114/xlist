import 'package:get/get.dart';

import 'package:xlist/pages/file/index.dart';
import 'package:xlist/pages/splash/index.dart';
import 'package:xlist/pages/detail/index.dart';
import 'package:xlist/pages/search/index.dart';
import 'package:xlist/pages/setting/index.dart';
import 'package:xlist/pages/notfound/index.dart';
import 'package:xlist/pages/homepage/index.dart';
import 'package:xlist/pages/document/index.dart';
import 'package:xlist/pages/directory/index.dart';
import 'package:xlist/pages/video_player/index.dart';
import 'package:xlist/pages/audio_player/index.dart';
import 'package:xlist/pages/setting/about/index.dart';
import 'package:xlist/pages/image_preview/index.dart';
import 'package:xlist/pages/setting/recent/index.dart';
import 'package:xlist/pages/setting/server/index.dart';
import 'package:xlist/pages/setting/preview/index.dart';
import 'package:xlist/pages/setting/favorite/index.dart';
import 'package:xlist/pages/setting/download/index.dart';

import 'package:xlist/routes/middlewares/auth_middleware.dart';
part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = _Paths.splash;

  static final routes = [
    unknownRoute,
    GetPage(name: _Paths.splash, page: () => SplashPage()),
    GetPage(
      name: _Paths.homepage,
      page: () => Homepage(),
      binding: HomepageBinding(),
      transitionDuration: Duration.zero,
    ),
    GetPage(
      name: _Paths.detail,
      page: () => DetailPage(),
      binding: DetailBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.search,
      page: () => SearchPage(),
      binding: SearchBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.directory,
      page: () => DirectoryPage(),
      binding: DirectoryBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.document,
      page: () => DocumentPage(),
      binding: DocumentBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.file,
      page: () => FilePage(),
      binding: FileBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.imagePreview,
      page: () => ImagePreviewPage(),
      binding: ImagePreviewBinding(),
      opaque: false,
      showCupertinoParallax: false,
      transition: Transition.fadeIn,
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.videoPlayer,
      page: () => VideoPlayerPage(),
      binding: VideoPlayerBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.audioPlayer,
      page: () => AudioPlayerPage(),
      binding: AudioPlayerBinding(),
      showCupertinoParallax: false,
      transition: Transition.downToUp,
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: _Paths.setting,
      page: () => SettingPage(),
      binding: SettingBinding(),
      children: [
        GetPage(
          name: _Paths.server,
          page: () => ServerPage(),
          binding: ServerBinding(),
        ),
        GetPage(
          name: _Paths.download,
          page: () => DownloadPage(),
          binding: DownloadBinding(),
        ),
        GetPage(
          name: _Paths.about,
          page: () => AboutPage(),
          binding: AboutBinding(),
        ),
        GetPage(
          name: _Paths.recent,
          page: () => RecentPage(),
          binding: RecentBinding(),
        ),
        GetPage(
          name: _Paths.favorite,
          page: () => FavoritePage(),
          binding: FavoriteBinding(),
        ),
        GetPage(
          name: _Paths.previewImage,
          page: () => SettingImagePage(),
          binding: SettingImageBinding(),
        ),
        GetPage(
          name: _Paths.previewAudio,
          page: () => SettingAudioPage(),
          binding: SettingAudioBinding(),
        ),
        GetPage(
          name: _Paths.previewVideo,
          page: () => SettingVideoPage(),
          binding: SettingVideoBinding(),
        ),
        GetPage(
          name: _Paths.previewDocument,
          page: () => SettingDocumentPage(),
          binding: SettingDocumentBinding(),
        ),
      ],
    ),
  ];

  static final unknownRoute = GetPage(
    name: _Paths.notfound,
    page: () => NotfoundPage(),
  );
}
