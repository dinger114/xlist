# Worklog

按 `xlist-execution-plan.md`（v2）执行，每个 Phase 完成追加一段。

---
Phase: 0
Agent: Hermes (deepseek-v4.1-flash)
Date: 2026-09-22
Base commit: f900fbe
End commit: 519a6ae
PR: （见 PR 链接）

## Summary

Phase 0 收尾 v1.1.0。原计划 5 个任务，实测开工前已完成 3 个（0.2/0.3/0.4），
本 Phase 只做了剩余的 0.1（补 CHANGELOG）与 0.5（补测试基线）。

## Tasks Completed

- [x] Task 0.1: 补 CHANGELOG v1.1.0
      版本号全部按 `pubspec.lock` 实测回填，非照抄提交信息（v1 计划里的
      build_runner 2.16.1 / flutter_gen 5.15.0 / analyzer 14.4.0 等已核对）
- [x] Task 0.2: 依赖自动更新 ignore list —— **开工前已完成**（用 dependabot，非 renovate）
- [x] Task 0.3: setup-flutter 复合 Action —— **开工前已完成**，实现优于计划
- [x] Task 0.4: build.yml concurrency + timeout + obfuscate —— **开工前已完成**
- [x] Task 0.5: 补测试基线 —— 37 → 117（+80）

## Metrics

- 测试数：37 → 117（+80）
- 新增测试文件：4 个（utils 33 例 / constants 19 例 / preview_helper 28 例 / storage 夹具）
- `flutter analyze`：0 error（30 warning 全在既有 lib/，新增文件 0 warning）
- `dart format --set-exit-if-changed lib test`：干净
- 运行时代码改动：**无**（本 Phase 只动 CHANGELOG.md 与 test/，未碰 lib/）

## 关于「真机冒烟」的说明

计划要求每个 PR 合并前做真机冒烟（启动 → 选服务器 → 浏览目录 → 播放视频 →
后台音频）。本 Phase **未做**，原因是本 Phase 没有改任何运行时代码，
冒烟实际只会验到 v1.1.0 的既有行为，对本次改动无判别力。
本 Phase 的可验证面在 CI（format / analyze / test）与测试断言本身。
Phase 1 起每有 lib/ 改动，冒烟恢复执行。

## 本次测试暴露的既存问题（已用测试记录现状，未改代码）

1. `CommonUtils.capitalize('')` 抛 RangeError（实现用 `substring(0,1)`）；
   `formatIjkTrack` 传空串同理。
2. `CommonUtils.sortObjectList` 的 `TIME_*` 分支用 `modified!`、`NAME_*` 用 `name!`
   断言：服务端返回缺该字段的条目时抛 TypeError，而调用方 `getObjectList`
   是整块 `try { ... } catch (e) {}`，所以对外表现为「列表空白」而非报错，
   排查困难。`SIZE_*` 分支已正确写成 `(size ?? 0)`，可参照修。**建议单开 PR 修。**
3. `PreviewHelper.isVideo` 对 `.strm` 硬编码为视频，即使用户从偏好里删掉 strm
   也仍识别（注释说明是有意设计）—— 已用测试锁住该语义。

## Blockers

- 无

## 已知覆盖缺口

- `PreviewHelper.isDocument` 里 `GetPlatform.isAndroid` 的分支取宿主 OS，
  单元测试跑在 macOS 上恒为非 Android，故「Android 只支持代码 + pdf」的
  逻辑无法在单测覆盖，只能真机验证。

## Next Phase

- Phase 1：路由迁 go_router + 主壳换 `MaterialApp.router`（53 处导航调用）
- **动手第一天必做**：Task 1.0 透视测试 —— `flutter_smart_dialog 4.9.8` 在
  router 模式下是否正常。这是全计划未验证的最大风险。
- 顺序提示（v2）：Phase 1 之后直接做 Phase 3（material_ui 解封），
  Phase 2（Provider）已降级为可选技术债。
