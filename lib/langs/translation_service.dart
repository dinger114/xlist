import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'en_us.dart';
import 'zh_hans.dart';

class TranslationService extends Translations {
  static Locale? get locale => Get.deviceLocale;
  static final fallbackLocale = Locale('en', 'US');

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': enUs,
        'zh_Hans': zhHans,
      };
}
