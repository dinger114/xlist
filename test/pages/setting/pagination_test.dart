import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// 验证 5.x 迁移后 favorite/recent 采用的「按 offset 分页」逻辑。
///
/// 这两个页面（收藏 / 最近浏览）的 getNextPageKey 用「已取条数」当 offset，
/// 并以「上一页不满 pageSize」判定末页 —— 与原 4.x 的
/// appendPage(_list, currentIndex + _list.length) / appendLastPage 语义一致。
///
/// 真机上库表只有 7 条记录（< pageSize=20），走不到多页分支，
/// 所以这里用假数据源把多页 / 末页 / 空列表都跑一遍。
///
/// 5.x 的两个语义坑（写测试时才确认，别按 4.x 直觉假设）：
///  1. fetchNextPage() 返回 void，异步完成后才更新 state，需 pumpEventQueue()。
///  2. hasNextPage 不会在「取到不满一页」时立刻变 false。要等**下一次**
///     fetchNextPage 探测到 getNextPageKey 返回 null 才置 false。这次探测
///     不会调用 fetchPage（即不打数据库），所以行为等价于原 appendLastPage。
///  3. refresh() 只重置 state（pages 置 null），不发起请求；第一页由布局层
///     看到 loadingFirstPage 后再拉。
void main() {
  const pageSize = 20;

  /// 复刻 controller 里的 getNextPageKey 逻辑
  int? nextPageKey(PagingState<int, String> state) {
    final pages = state.pages;
    if (pages != null && pages.isNotEmpty && pages.last.length < pageSize) {
      return null;
    }
    return (pages ?? const <List<String>>[])
        .fold<int>(0, (sum, p) => sum + p.length);
  }

  /// 用 [total] 条假数据构造 controller，记录取过的 offset 序列
  Harness build(int total) {
    final h = Harness();
    h.ctrl = PagingController<int, String>(
      getNextPageKey: nextPageKey,
      fetchPage: (offset) async {
        h.offsets.add(offset);
        if (offset >= total) return const <String>[];
        final end = (offset + pageSize) > total ? total : offset + pageSize;
        return List<String>.generate(end - offset, (i) => 'item${offset + i}');
      },
    );
    return h;
  }

  /// 取一页并等待异步完成
  Future<void> fetch(Harness h) async {
    h.ctrl.fetchNextPage();
    await pumpEventQueue();
  }

  test('多于一页：offset 依次 0 → 20 → 40，条目数正确', () async {
    final h = build(45); // 20 + 20 + 5
    await fetch(h);
    await fetch(h);
    await fetch(h);

    expect(h.offsets, [0, 20, 40], reason: 'offset 不能重复或跳号');
    expect(h.ctrl.value.items!.length, 45);
  });

  test('取到不满一页后，再做一次探测不产生新请求并结束', () async {
    final h = build(45);
    await fetch(h);
    await fetch(h);
    await fetch(h);
    expect(h.ctrl.value.items!.length, 45);

    // 末页只有 5 条；此时 hasNextPage 仍为 true（5.x 语义）
    await fetch(h);
    expect(h.offsets, [0, 20, 40], reason: '探测不应命中数据库');
    expect(h.ctrl.value.hasNextPage, isFalse);
    expect(h.ctrl.value.items!.length, 45);
  });

  test('刚好整页：末页满页时需再取一次空页来判定结束', () async {
    final h = build(40); // 正好 2 页

    await fetch(h);
    expect(h.offsets, [0]);
    await fetch(h);
    expect(h.offsets, [0, 20]);

    // 第 2 页正好满 20 条 -> 尚不能判定末页 -> 再取一次得到空页
    await fetch(h);
    expect(h.offsets, [0, 20, 40]);
    expect(h.ctrl.value.items!.length, 40);

    // 空页到达后再探测才结束
    await fetch(h);
    expect(h.offsets, [0, 20, 40], reason: '判定结束后不再请求');
    expect(h.ctrl.value.hasNextPage, isFalse);
    expect(h.ctrl.value.items!.length, 40);
  });

  test('空列表：单次请求后为空，探测一次后结束', () async {
    final h = build(0);
    await fetch(h);
    expect(h.offsets, [0]);
    expect(h.ctrl.value.items!.isEmpty, isTrue);

    await fetch(h);
    expect(h.offsets, [0], reason: '空列表不应重复请求');
    expect(h.ctrl.value.hasNextPage, isFalse);
  });

  test('不足一页：单次请求拿到全部，探测后结束', () async {
    final h = build(7);
    await fetch(h);
    expect(h.offsets, [0]);
    expect(h.ctrl.value.items!.length, 7, reason: '7 < pageSize 应一次取完');

    await fetch(h);
    expect(h.offsets, [0]);
    expect(h.ctrl.value.hasNextPage, isFalse);
  });

  test('filterItems 删除后条目正确，且不重置已加载的分页', () async {
    final h = build(45);
    await fetch(h);
    await fetch(h);
    await fetch(h);
    expect(h.ctrl.value.items!.length, 45);

    // 删除 item0 与 item44（复刻 deleteFavorite / deleteRecent 的新写法）
    h.ctrl.value =
        h.ctrl.value.filterItems((e) => e != 'item0' && e != 'item44');

    final items = h.ctrl.value.items!;
    expect(items.length, 43);
    expect(items.contains('item0'), isFalse);
    expect(items.contains('item44'), isFalse);
    expect(items.contains('item1'), isTrue);
    expect(h.ctrl.value.pages!.length, 3, reason: '删除不应清掉已加载分页');
  });

  test('refresh 重置 state；再取一次回到第一页', () async {
    final h = build(45);
    await fetch(h);
    await fetch(h);
    expect(h.ctrl.value.items!.length, 40);

    h.ctrl.refresh(); // 复刻 clearFavorite / clearRecent 的新写法
    expect(h.ctrl.value.pages, isNull, reason: 'refresh 只重置，不请求');
    expect(h.ctrl.value.hasNextPage, isTrue);
    expect(h.ctrl.value.error, isNull);

    // 布局层随后触发第一页
    await fetch(h);
    expect(h.offsets.last, 0);
    expect(h.ctrl.value.items!.length, 20);
  });
}

/// 简单的测试夹具（项目 SDK 未启用 records 语法，故用类）
class Harness {
  late PagingController<int, String> ctrl;
  final List<int> offsets = <int>[];
}
