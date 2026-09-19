import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:media_kit/media_kit.dart';

import 'package:xlist/global.dart';
import 'package:xlist/themes.dart';
import 'package:xlist/components/index.dart';
import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/pages/splash/index.dart';
import 'package:xlist/langs/translation_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  Global.init().then((e) => runApp(Phoenix(child: XlistApp())));
}

class XlistApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(1080, 1920),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => GetMaterialApp(
        title: 'Xlist',
        theme: Themes.light as ThemeData?,
        darkTheme: Themes.dark as ThemeData?,
        themeMode: ThemeMode.light,
        home: SplashPage(),
        initialBinding: SplashBinding(),
        defaultTransition: Transition.cupertino,
        debugShowCheckedModeBanner: false,
        initialRoute: AppPages.INITIAL,
        getPages: AppPages.routes,
        unknownRoute: AppPages.unknownRoute,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: FlutterSmartDialog.init(
              toastBuilder: (String msg) => ToastComponent(message: msg),
            )(context, child),
          );
        },
        translations: TranslationService(),
        locale: TranslationService.locale,
        fallbackLocale: TranslationService.fallbackLocale,
      ),
    );
  }
}
