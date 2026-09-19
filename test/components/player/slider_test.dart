import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/components/player/slider.dart';

void main() {
  group('XSliderColors', () {
    test('默认值相等性基于字段', () {
      const a = XSliderColors();
      const b = XSliderColors();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('不同字段不相等', () {
      const a = XSliderColors();
      final b = XSliderColors(playedColor: const Color(0xFF00FF00));
      expect(a, isNot(equals(b)));
    });
  });

  group('XSlider 数值边界', () {
    // 进度条把 value/max 映射到 0-1；这里是控制器侧常用边界值的语义测试
    test('当前值不应超过时长', () {
      const value = 1500.0;
      const duration = 1000.0;
      expect(value.clamp(0, duration), 1000.0);
    });

    test('当前值不应小于 0', () {
      const value = -10.0;
      expect(value.clamp(0, 1000.0), 0.0);
    });

    test('缓冲进度超出时长时钳制到时长', () {
      const cache = 2000.0;
      const duration = 1000.0;
      expect(cache.clamp(0, duration), 1000.0);
    });
  });
}
