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

---
Phase: 1
Agent: Hermes (deepseek-v4.1-flash)
Date: 2026-09-22
Base commit: bda44a6
End commit: （见 PR）
PR: （见 PR 链接）

## Summary

Phase 1 原计划「路由迁 go_router + 主壳换 MaterialApp.router」。开工先做了一个
10 分钟的证伪实验（`test/routes/getx_nav_shell_test.dart`），结论推翻了整个计划：

**裸 `MaterialApp` + `navigatorKey: Get.key` + `GetObserver` 下，GetX 的导航 /
`Get.arguments` / binding / 控制器生命周期全部照常工作**（含 pop 时自动销毁
路由级 controller、二次进入不拿陈旧实例）。所以 53 处导航调用、32 处
`Get.arguments`、21 个 GetPage 一行都不用改，**go_router 不该引入**
（它还额外带来 material_ui 依赖：18.0.0+ 会污染依赖树）。

于是 Phase 1 缩减为「主壳换壳 + 补齐 GetMaterialApp 原先代劳的三件事」，
工期从约 3 周降到不到 1 天。

## Tasks Completed

- [x] Task 1.0: 透视测试 —— `flutter_smart_dialog` 在非 GetMaterialApp 下可用
      （上一段已 PASS；本轮不再重复）
- [x] Task 1.1: `lib/routes/app_router.dart` —— `AppPages.routes` 扁平化
      （GetX 的 children 是字符串拼接语义，`/setting` + `/server`）
      + `onGenerateRoute` / `onUnknownRoute`
- [x] Task 1.2: `lib/main.dart` 换 `MaterialApp`：
      `navigatorKey: Get.key`、`GetObserver(cb, Get.routing)`、
      `initialRoute` / `onGenerateRoute` / `onUnknownRoute`
- [x] Task 1.3: i18n 补齐 —— `Get.addTranslations()` + `Get.locale` 手动注册、
      `SplashBinding().dependencies()` 手动执行、加 `flutter_localizations`
- [x] Task 1.4: 移除 go_router（本方案不需要），依赖树保持 material_ui-free
- [x] Task 1.5: 真机验证（见下）

## Metrics

- 测试数：117 → 150（+33）
- 新增测试文件：5 个（`test/routes/`）
- `flutter analyze`：0 error
- `dart format --set-exit-if-changed lib test`：干净
- 依赖树：`go_router` 0 处、`material_ui` 0 处

## 真机验证（Pixel 6 Pro / raven / Android 17，release 包，USB 装机）

路由日志用 `--dart-define=XLIST_ROUTE_LOG=true` 打开（`Global.routeLog`），
从 logcat 读实际路由，而不是靠像素猜：

- 启动：`XLIST_GEN >>> name=/ page=/` → `XLIST_ROUTE >>> /` →
  `XLIST_GEN >>> name=/homepage` → `XLIST_ROUTE >>> /homepage`
  （`Get.offAndToNamed` 在裸 shell 下正常）
- 点导航栏图标 → `XLIST_ROUTE >>> /setting`（命名路由 ✓）
- 设置页点条目 → `XLIST_ROUTE >>> /setting/server`（**嵌套路由** ✓）
- 点文件夹进详情页 → 无异常（这条原先崩在 `Get.arguments` 为 null）
- 返回键回首页：颜色直方图与首页逐项一致
- 全程无 `NoSuchMethodError` / `Null check` / `Failed assertion`

## 本轮抓到并修掉的两个回归（都是换壳引入的）

1. **中文环境弹对话框必崩**：`Null check operator used on a null value`
   → `MaterialLocalizations.of` → `AlertDialog.build`。
   `supportedLocales` 声明了 `zh_Hans` 却只挂 `DefaultMaterialLocalizations`
   （仅英文），zh 解析不到 delegate → `of()` 返回 null → 对话框里的 `!` 崩。
   修：补 Global*/Cupertino delegate。回归测试 `localization_delegates_test.dart`。

2. **所有 `Get.arguments` 为 null**：点文件夹进详情页
   `NoSuchMethodError: [](“path”) on null`（`detail/controller.dart:26`）。
   `GetObserver([routing, _routeSend])` 的**第二个**位置参数才是被写入 `args`、
   且 `Get.arguments` 读取的那个对象；只传回调等于没人写。
   修：`GetObserver(cb, Get.routing)`。回归测试 `get_arguments_wiring_test.dart`
   （带对照断言，直接证明漏传时为 null）。

   另有**时序**问题：GetX 原本在路由创建**之后**才写 args，而 binding 在路由
   **构建时**执行 —— 字段初始化里读 `Get.arguments` 的 controller 会拿到 null。
   修：在 `AppRouter.onGenerateRoute` 里、跑 binding 之前先写。

## 排查过程中的坑（值得记下来）

- **release 包里 `print` 的输出在 Android 会被丢弃**（stdout 未接 logcat），
  必须用 `debugPrint` 才看得到 —— 一度误判成「GetObserver 回调没触发」。
- `adb shell input tap` 打在**状态栏**区域会拉下通知栏（y≈72 就中招），
  应用自己的导航栏在状态栏之下（本机 ≈y200-420）。
- Flutter 对**初始路由**不认识时只打印 "Could not navigate to initial route"
  并回退 `/`，**不走 `onUnknownRoute`**；`onUnknownRoute` 只在 push 未知路由
  时生效。生产里 initialRoute 恒为 `/`，不受影响。
- 页面里大量 `10.r` / `50.sp` 依赖 `ScreenUtilInit`，测试宿主缺了会抛
  `LateInitializationError`（不是路由问题）。

## 已知覆盖缺口

- 业务页（详情/预览/设置子页等）在单测里**不构建**：它们全都依赖完整 DI
  （`DatabaseService` / `DownloadService` / …）并直接打网络，搭齐会变成假的
  集成测试，且失败信息无法区分「路由坏了」和「环境缺件」。所以单测只断言
  「`onGenerateRoute` 为每条路由返回正确的 Route」，页面真实构建靠真机。
- 真机上未逐条走完 20 条路由（预览/播放等需要具体媒体文件与服务器），
  已验证的是：splash→homepage、命名路由 `/setting`、嵌套 `/setting/server`、
  文件夹进详情页、返回。
- 设备中途自动锁屏，后续点按被 keyguard 吞掉（解锁需用户 PIN，未代猜）。

## Next Phase

- Phase 3：解封 material_ui（升 flex_color_scheme 9 / cached_network_image 4 /
  flutter_smart_dialog 5 等 5 包）。主壳已在 Phase 1 换掉，唯一编译冲突
  （`GetMaterialApp.theme:`）已消除。

---
Phase: 3
Agent: Hermes (deepseek-v4.1-flash)
Date: 2026-09-22
Base commit: 267a7c9
End commit: （见 PR）
PR: （见 PR 链接）

## Summary

Phase 3 的目标是**解封 material_ui**：升 5 个此前被钉死的包
（flex_color_scheme 9 / cached_network_image 4 / flutter_smart_dialog 5 /
dynamic_color 2 / animations 3）。计划里写的做法是「各文件 import 从
`flutter/material.dart` 换成 `material_ui/material_ui.dart`」。

**实测发现这个做法是错的**，会静默损坏 UI。原因：

1. `flutter/material.dart` **不** re-export `material_ui`，两套各有自己的
   `ThemeData` / `ColorScheme` / `MaterialLocalizations`（同名不同类）；
2. 彼此的 `Theme.of()` 找不到对方时**不抛异常，而是静默返回
   `ThemeData.fallback()`** —— 实测用可区分颜色验证：跨库读到的 primary 是
   默认紫 (103,80,164)，不是品牌色 (119,120,220)。这种失败 analyze 抓不到、
   单测(不比对颜色)也抓不到；
3. 本项目**只有 5 个包**已迁 material_ui，**约 50 个直接依赖仍用
   `flutter/material.dart`**（media_kit / adaptive_dialog /
   infinite_scroll_pagination / syncfusion_flutter_pdfviewer / photo_view /
   keframe / pull_down_button / easy_refresh / modal_bottom_sheet …，其中
   syncfusion 一家就 35 个文件）。把我们的 60 个文件换过去 → 那 50 个包全部
   落进 fallback 主题。

所以改用**双主题桥接**：主壳保持 flutter/material（那 50 个包行为不变），在
`MaterialApp.builder` 上挂 `ThemeBridge`，给 material_ui 侧补一层主题与本地化。
5 个包仍然升到 new（这才是「解封」的实质），只是不需要把全项目 import 换掉。

## Tasks Completed

- [x] Task 3.2: cached_network_image 3.4.1 → 4.0.0（material_ui 进树）
- [x] Task 3.3: flex_color_scheme 8.4.0 → 9.0.0（ThemeData 冲突如期出现，2 处）
- [x] Task 3.4: flutter_smart_dialog 4.9.8+10 → 5.3.0
- [x] Task 3.5: dynamic_color 1.7.0 → 2.1.0 + animations 3.0.0
      （**解除 dependency_overrides 里的钉子**，该钉子本就是为这个冲突打的）
- [x] 新增 `lib/components/theme_bridge.dart`（主题 + 本地化桥接）
- [x] `lib/themes.dart` 改为双主题（muiLight/muiDark + light/dark 同源同色）
- [x] 真机验证

## Metrics

- 测试数：150 → 166（+16）
- 新增测试文件：2 个（`test/main_wiring_test.dart`、`test/components/theme_bridge_test.dart`）
- `flutter analyze`：0 error
- `dart format --set-exit-if-changed lib test`：干净
- 5 个目标包全部升到预期版本，`material_ui 1.4.0` / `cupertino_ui 1.1.1` 进树

## 本轮抓到并修掉的两个坑（都是实测出来的，不是推演）

1. **只补主题不够：smart_dialog 5.3 的 dialog 抛 `No MaterialLocalizations found.`**
   该版本的 dialog 走 material_ui 的 `MaterialLocalizations.of`，而主壳挂的是
   flutter 版 delegate。桥接层补 `mui.GlobalMaterialLocalizations.delegate` 解决。
   （toast 不受影响 —— 它用 wrap 模式，不依赖 MaterialLocalizations。）
2. **`Localizations` 是遮蔽而非叠加**：光挂 mui 的 delegate，会让桥接层**之下**的
   flutter widget（`AppBar`）也报 `No MaterialLocalizations found.`。
   修法：桥接层同时挂**两侧** delegate，并与主壳共用同一份清单
   （`ThemeBridge.localizationsDelegates`），避免两处漂移。
   另外 flutter 的 `Localizations` 会 assert「delegates 里必须有 WidgetsLocalizations」，
   只挂 mui + Material delegate 会直接 assert 失败。

## 真机验证（Pixel 6 Pro / Android 17，release 包，USB 装机）

- 启动 → `/` → `/homepage`，点导航栏 → `/setting`，全程无异常
- 主题核对用**颜色**而不是「没崩」：首页 / 设置页截图里品牌色
  (119,120,220) 分别 1104 / 691 像素，**mui fallback 紫 (103,80,164) 为 0 像素**
  → 没有任何 widget 掉进 fallback 主题
- logcat 全程无 `NoSuchMethodError` / `Null check` / `Failed assertion` /
  `No MaterialLocalizations` / FlexColorScheme WARNING

## 已知覆盖缺口

- 未在真机上遍历所有用到这 5 个包的页面（图片预览、收藏、最近、视频/音频页
  的封面等），只走了首页与设置页。
- 真机是亮色主题（app `themeMode` 固定 light），暗色主题只能靠单测断言
  brightness 与主色一致。
- 计划 Task 3.6 还写了「发 v1.2.0 / 打 tag / CHANGELOG 里写『退役 GetX、迁
  go_router、迁 Provider』」—— 那些前提在本方案下不成立（GetX 保留、
  go_router 未引入、Provider 未迁），故未执行打 tag；CHANGELOG 按实际改动写。

## Next Phase

- Phase 4：Android arm64 专项优化（APK 体积 < 40MB、冷启动、权限清理）。
