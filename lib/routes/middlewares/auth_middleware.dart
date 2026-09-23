import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';

import 'package:xlist/routes/app_pages.dart';
import 'package:xlist/storages/user_storage.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    // 可以在这里进行跳转前的逻辑处理
    // 判断登录
    // ...

    UserStorage storage = Get.find<UserStorage>();
    if (GetUtils.isNullOrBlank(storage.serverId.val)!) {
      return RouteSettings(name: Routes.homepage);
    }

    // 显式返回 null：GetX 约定 null 表示「放行」，不拦截本次导航。
    return null;
  }
}
