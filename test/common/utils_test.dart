import 'package:flutter_test/flutter_test.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/models/index.dart';

/// `CommonUtils` 里纯函数的单元测试。
///
/// 这些函数被 4 个页面共用（homepage / detail / favorite / recent 都调用
/// `sortObjectList`），但此前完全没有测试。Phase 0.5 补基线时优先补它们：
/// 纯函数、无 GetX 依赖、出错影响面大。
ObjectModel _obj(String name, int type, {DateTime? modified, int? size}) {
  final o = ObjectModel();
  o.name = name;
  o.type = type;
  o.modified = modified;
  o.size = size;
  return o;
}

ObjectModel _folder(String name, {DateTime? modified, int? size}) =>
    _obj(name, FileType.folder, modified: modified, size: size);

ObjectModel _file(String name, {DateTime? modified, int? size}) =>
    _obj(name, FileType.video, modified: modified, size: size);

void main() {
  group('formatFileSize', () {
    test('小于 1KB 显示为 B，不带小数', () {
      expect(CommonUtils.formatFileSize(0), '0B');
      expect(CommonUtils.formatFileSize(1), '1B');
      expect(CommonUtils.formatFileSize(1023), '1023B');
    });

    test('1024 是 KB 的门槛（边界值）', () {
      expect(CommonUtils.formatFileSize(1023), '1023B');
      expect(CommonUtils.formatFileSize(1024), '1.00KB');
    });

    test('KB 保留两位小数', () {
      expect(CommonUtils.formatFileSize(1536), '1.50KB');
    });

    test('1MB 门槛：1048575 仍是 KB，1048576 转 MB', () {
      expect(CommonUtils.formatFileSize(1048575), '1024.00KB');
      expect(CommonUtils.formatFileSize(1048576), '1.00MB');
    });

    test('1GB 门槛：1073741823 仍是 MB，1073741824 转 GB', () {
      expect(CommonUtils.formatFileSize(1073741823), '1024.00MB');
      expect(CommonUtils.formatFileSize(1073741824), '1.00GB');
    });

    test('超过 1GB 仍用 GB 表示，不会溢出成 TB 单位', () {
      // 5GB
      expect(CommonUtils.formatFileSize(5 * 1024 * 1024 * 1024), '5.00GB');
    });
  });

  group('formatFileNme', () {
    test('去掉扩展名', () {
      expect(CommonUtils.formatFileNme('movie.mp4'), 'movie');
    });

    test('多个点号只去掉最后一段', () {
      expect(CommonUtils.formatFileNme('my.movie.2026.mkv'), 'my.movie.2026');
    });

    test('无扩展名时原样返回', () {
      expect(CommonUtils.formatFileNme('README'), 'README');
    });

    test('隐藏文件（仅以点开头）应原样保留', () {
      // p.basenameWithoutExtension('.gitignore') == '.gitignore'
      expect(CommonUtils.formatFileNme('.gitignore'), '.gitignore');
    });
  });

  group('capitalize', () {
    test('首字母大写，其余不变', () {
      expect(CommonUtils.capitalize('abc'), 'Abc');
      expect(CommonUtils.capitalize('aBc'), 'ABc');
    });

    test('已经是首字母大写时不重复处理', () {
      expect(CommonUtils.capitalize('Abc'), 'Abc');
    });

    test('中文开头不报错（无大小写，原样返回）', () {
      expect(CommonUtils.capitalize('中文'), '中文');
    });

    test('空字符串会抛 RangeError（当前实现的已知边界行为）', () {
      // 记录现状而非期望：capitalize 用 substring(0,1)，
      // 空串会抛 RangeError。formatIjkTrack 传入空 track 时同样触发。
      expect(() => CommonUtils.capitalize(''), throwsRangeError);
    });
  });

  group('formatIjkTrack', () {
    test("'und' 视作未知，显示为「未知」", () {
      expect(CommonUtils.formatIjkTrack('und'), '未知');
    });

    test('普通 track 首字母大写', () {
      expect(CommonUtils.formatIjkTrack('jpn'), 'Jpn');
    });
  });

  group('randomInt', () {
    test('结果落在 [min, max) 内', () {
      for (var i = 0; i < 50; i++) {
        final v = CommonUtils.randomInt(10, 20);
        expect(v, greaterThanOrEqualTo(10));
        expect(v, lessThan(20));
      }
    });

    test('min == max 时恒等于该值', () {
      expect(CommonUtils.randomInt(7, 7), 7);
    });
  });

  group('sortObjectList', () {
    test('文件夹永远排在文件前面，与排序方式无关', () {
      // 文件夹名字母序在文件之后，仍应在前
      final list = [
        _file('aaa.mp4', modified: DateTime(2026, 1, 1), size: 1),
        _folder('zzz', modified: DateTime(2020, 1, 1), size: 1),
      ];
      for (final type in [
        SortType.timeDesc,
        SortType.timeAsc,
        SortType.nameDesc,
        SortType.nameAsc,
        SortType.sizeDesc,
        SortType.sizeAsc,
      ]) {
        final r = CommonUtils.sortObjectList(List.of(list), type);
        expect(r.first.type, FileType.folder,
            reason: 'sortType=$type 时文件夹未排在前');
        expect(r.last.type, isNot(FileType.folder));
      }
    });

    test('时间降序', () {
      final list = [
        _file('a', modified: DateTime(2026, 1, 1)),
        _file('b', modified: DateTime(2026, 3, 1)),
        _file('c', modified: DateTime(2026, 2, 1)),
      ];
      final r = CommonUtils.sortObjectList(list, SortType.timeDesc);
      expect(r.map((e) => e.name), ['b', 'c', 'a']);
    });

    test('时间升序', () {
      final list = [
        _file('a', modified: DateTime(2026, 1, 1)),
        _file('b', modified: DateTime(2026, 3, 1)),
        _file('c', modified: DateTime(2026, 2, 1)),
      ];
      final r = CommonUtils.sortObjectList(list, SortType.timeAsc);
      expect(r.map((e) => e.name), ['a', 'c', 'b']);
    });

    test('名称降序', () {
      final list = [_file('b'), _file('a'), _file('c')];
      final r = CommonUtils.sortObjectList(list, SortType.nameDesc);
      expect(r.map((e) => e.name), ['c', 'b', 'a']);
    });

    test('名称升序', () {
      final list = [_file('b'), _file('a'), _file('c')];
      final r = CommonUtils.sortObjectList(list, SortType.nameAsc);
      expect(r.map((e) => e.name), ['a', 'b', 'c']);
    });

    test('大小降序', () {
      final list = [
        _file('a', size: 100),
        _file('b', size: 300),
        _file('c', size: 200),
      ];
      final r = CommonUtils.sortObjectList(list, SortType.sizeDesc);
      expect(r.map((e) => e.name), ['b', 'c', 'a']);
    });

    test('大小升序', () {
      final list = [
        _file('a', size: 100),
        _file('b', size: 300),
        _file('c', size: 200),
      ];
      final r = CommonUtils.sortObjectList(list, SortType.sizeAsc);
      expect(r.map((e) => e.name), ['a', 'c', 'b']);
    });

    test('不修改传入的原列表（返回新列表）', () {
      final list = [_file('b'), _file('a')];
      final before = List.of(list);
      CommonUtils.sortObjectList(list, SortType.nameAsc);
      // 注意：内部对 folders/files 是新数组，但 folders 排序后拼接返回；
      // 原 list 内容与顺序都不应被改动
      expect(list.map((e) => e.name), before.map((e) => e.name));
    });

    test('空列表返回空列表', () {
      expect(CommonUtils.sortObjectList([], SortType.nameAsc), isEmpty);
    });

    test('只有文件时不做文件夹分组', () {
      final list = [_file('b'), _file('a')];
      final r = CommonUtils.sortObjectList(list, SortType.nameAsc);
      expect(r.length, 2);
      expect(r.map((e) => e.type).toSet(), {FileType.video});
    });

    test('只有文件夹时同样排序', () {
      final list = [_folder('b'), _folder('a')];
      final r = CommonUtils.sortObjectList(list, SortType.nameAsc);
      expect(r.map((e) => e.name), ['a', 'b']);
    });

    test('未知 sortType 不抛异常，且仍做文件夹分组', () {
      final list = [
        _file('a', modified: DateTime(2026, 1, 1)),
        _folder('z', modified: DateTime(2026, 1, 1)),
      ];
      final r = CommonUtils.sortObjectList(list, 999);
      expect(r.length, 2);
      expect(r.first.type, FileType.folder);
    });

    test('大小排序把 null size 当作 0（不抛异常）', () {
      final list = [
        _file('a', size: 10),
        _file('b'), // size 为 null
      ];
      final r = CommonUtils.sortObjectList(list, SortType.sizeAsc);
      expect(r.first.name, 'b', reason: 'null 当 0 处理，应排最前');
    });

    test('时间排序遇到 modified 为 null 会抛（当前实现的已知风险）', () {
      // 记录现状：TIME_* 分支用 modified! 断言，null 会抛。
      // 服务端返回缺失 modified 的条目时，homepage/detail 的 getObjectList
      // 会整块进 catch，表现为「列表空白」而非报错。
      final list = [
        _file('a', modified: DateTime(2026, 1, 1)),
        _file('b'), // modified 为 null
      ];
      expect(
        () => CommonUtils.sortObjectList(list, SortType.timeDesc),
        throwsA(isA<TypeError>()),
      );
    });

    test('名称排序遇到 name 为 null 会抛（当前实现的已知风险）', () {
      final list = [
        _file('a'),
        _file('b')..name = null,
      ];
      expect(
        () => CommonUtils.sortObjectList(list, SortType.nameAsc),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
