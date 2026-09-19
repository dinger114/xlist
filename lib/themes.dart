import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart' hide ThemeData;

class Themes {
  // Light
  static final light = FlexThemeData.light(
    scheme: FlexScheme.flutterDash,
    primary: Color(0xFF7778dc),
    secondary: Color(0xFF81aad3),
  ).copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );

  // Dark
  static final dark = FlexThemeData.dark(
    scheme: FlexScheme.flutterDash,
    primary: Color(0xFF7778dc),
    secondary: Color(0xFF81aad3),
  ).copyWith(
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
}
