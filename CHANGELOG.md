# Changelog

## [1.3.0] - 待定

### Dependencies（material_ui 解封）

- `flex_color_scheme` 8.4.0 → **9.0.0**
- `cached_network_image` 3.4.1 → **4.0.0**
- `flutter_smart_dialog` 4.9.8+10 → **5.3.0**
- `dynamic_color` 1.7.0 → **2.1.0**（解除 `dependency_overrides` 里的钉子）
- `animations` 2.0.11 → **3.0.0**
- 这 5 个包自以上版本起改用独立的 `material_ui` / `cupertino_ui` 包，此前被
  钉在旧版本无法升级

### Changed

- 新增 `lib/components/theme_bridge.dart`：**主题 + 本地化桥接层**，挂在
  `MaterialApp.builder` 上，为已迁 material_ui 的包补上 material_ui 版主题与
  `MaterialLocalizations`。主壳仍是 flutter/material —— 本项目约 50 个直接依赖
  （media_kit / adaptive_dialog / infinite_scroll_pagination / syncfusion /
  photo_view …）尚未迁 material_ui，所以**不能**把 60 个文件全量换 import
- `lib/themes.dart` 改为同时提供两套主题：`muiLight`/`muiDark`（flex9 产出，
  供 material_ui 侧）与 `light`/`dark`（转换而来，供主壳与 flutter 侧），
  两套同源同色

### Bug Fixes

- 修复 smart_dialog 5.3 弹 **dialog** 抛 `No MaterialLocalizations found.`：
  该版本的 dialog 走 material_ui 的 `MaterialLocalizations.of`，而主壳挂的是
  flutter 版的 delegate。桥接层补 `mui.GlobalMaterialLocalizations.delegate`
- 修复桥接层**遮蔽**上文本地化的问题：`Localizations` 是 `InheritedWidget`，
  只挂 mui delegate 会让层内的 flutter widget（`AppBar` 等）也报
  `No MaterialLocalizations found.`。故桥接层同时挂两侧 delegate，并与主壳
  共用同一份清单（避免两处漂移）
- 消除 FlexColorScheme 的 `primaryLightRef/secondaryLightRef is null` 警告

### Tests

- 测试基线 150 → 166：新增 `test/main_wiring_test.dart`（按 `main.dart` 的真实
  接线验证 toast / dialog / loading 与 mui 主题可达）与
  `test/components/theme_bridge_test.dart`（桥接回归，含「不架桥时会静默退回
  fallback 主题」的对照断言）

### Performance（Phase 4：Android arm64 专项优化）

- **APK 46.1MB → 19.7MB（-57%）**，主因是开启 legacy JNI 打包（见下）
- 开启 `--tree-shake-icons`：MaterialIcons 1.6MB→7.5KB（-99.5%）、
  FontAwesome 414KB→2.6KB（-99.4%）、CupertinoIcons 258KB→8.8KB（-96.6%）。
  Makefile 的 `release-android`/`release-aab` 原本用 `--no-tree-shake-icons`，
  与 CI 不一致，已统一为开启。全仓无动态构造 `IconData(...codePoint:...)`，
  无字形被误剥风险
- 开启 R8 full mode（`android.enableR8.fullMode=true`）
- 开启资源收缩（`shrinkResources false → true`）

### Changed（体积关键项）

- **`packaging { jniLibs { useLegacyPackaging = true } }`**：这是本次体积
  下降的**主要**原因。AGP 9 默认 `useLegacyPackaging=false`（即
  `extractNativeLibs=false`），要求 `.so` 页对齐且**不压缩**存储，于是
  `libmpv`(11.8MB) / `libflutter`(11.2MB) / `libapp`(12.4MB) 等约 37MB 的
  native 库全部以 STORED 进包，压缩后体积等于原始体积。改为 deflate 压缩后
  这部分 37.6MB → 16.5MB。
  **代价**：安装时解压 `.so` 到 data 目录、占用 ROM 更多、启动略慢。
  实测冷启动 10 次平均：基线 265ms → 262ms（在噪声内，无可见回退）。

### Android

- 支持 per-app language（Android 13+）：新增
  `res/xml/locales_config.xml`（en / zh），Activity 挂
  `android:localeConfig`
- 清理权限：移除 `READ_PHONE_STATE`、`ACCESS_WIFI_STATE`（全仓 `lib/` 与
  `android/` 零引用）
- 删除 `web/` 目录（CI 只构建 Android；`web/` 未被任何 Dart 代码引用，
  仅在 `ci.yml` 的 `paths-ignore` 里出现过，已一并清理）

### 未做（实测后判定为不值得）

- **Baseline Profile（计划 Task 4.5）**：搭通并实测后**放弃并移除**。
  原因是收益与 262ms 的启动耗时不相称 —— baseline profile 只 AOT 优化
  `:app` 里的 Java/Kotlin，而本 app 启动重活全在 Dart 侧（`Global.init()`
  串行 await GetStorage + 3 个 Storage + 7 个 Service 后才 `runApp`），
  跑的是 libapp.so 里的 AOT 机器码，profile 覆盖不到；`:app` 侧只有
  一个 FlutterActivity 空壳。预估收益 3-8ms（约 1-3%），不值得背一个
  Gradle 子模块。实测 `:app:generateReleaseBaselineProfile` 虽报
  BUILD SUCCESSFUL，但所有 task 都是 UP-TO-DATE、产物目录为空，
  实际未产出 profile
- **`assets/` 压缩（原计划 Task 4.4）**：实测收益极小 —— `assets/` 磁盘
  仅 140KB，进包后 `flutter_assets` 仅 0.66MB，最大的还是 `NOTICES.Z`
  (137KB) 与 font_awesome 字体，无可观可减项。AGP 侧的 `shrinkResources`
  已开启

### 未做（超出本 Phase 范围，留待决策）

- **Impeller 仍为关闭状态**（manifest 里 `EnableImpeller=false`，且仓库未
  记录关闭原因）。这是冷启动真正的杠杆（Flutter 现默认 Impeller，关掉等于
  回退 Skia），但属图形后端切换，需真机目视对比渲染效果，本轮无视觉验收
  手段，未动

## [Unreleased]

### Bug Fixes

- **修复视频播放控制栏变灰块、音量/亮度手势失效**（真机 Pixel 6 Pro 实测）。
  `DefaultPanel.build` 返回的是 `Positioned.fill(...)`，但调用处是
  `Stack > Positioned.fill > Obx > DefaultPanel`，中间隔了一层 `Obx`。
  `Positioned` 的父级必须**直接**是 `Stack`，隔了之后 `ParentDataWidget`
  断言失败：`Incorrect use of ParentDataWidget ... MultiChildLayoutParentData`。
  debug 下是红屏，**release 下 Flutter 的 `ErrorWidget` 是个灰色方块** ——
  所以表现为控制栏灰块且其子树上手势全部失效。
  改为 `build` 返回 `Stack`（铺满交由调用处的 `Positioned.fill`），
  并新增 `test/components/player/default_panel_test.dart` 用真实层级
  （`Stack>Positioned.fill>Obx>DefaultPanel` + `navigatorKey: Get.key` 接线）
  守住该断言（已验证：还原此 bug 该测试即失败）

- **修复 alist 的 HLS（m3u8）一直转圈加载不出来**。
  `PlayerHelper.setOption` 原为 m3u8 设 `cache-secs=120`。实测该站点的分段是
  ~22.5MB / 60s（约 3Mbps、1080p），120s 需预缓冲约 45MB，紧贴
  `demuxer-max-bytes=50MiB` 的上限；码率更高的源则 120s > 50MiB，
  缓存永远填不满 → 一直转圈。收敛为 `cache-secs=20`（约 7.5MB）并加
  `cache-pause=yes` / `cache-pause-wait=3`。真机确认可正常播放。
  注：该 m3u8 的分段文件名为 `*.jpg` 但内容是 MPEG-TS；已验证**不是**原因
  （libmpv 内嵌的 ffmpeg n6.0 中扩展名白名单只对 `file://` 生效）

### Added

- 新增播放诊断开关 `XLIST_MPV_LOG`（`--dart-define=XLIST_MPV_LOG=true`）：
  把 mpv 后端日志经 `debugPrint` 打到 logcat。此前 media_kit 的诊断走 `print`，
  release 下被丢弃，导致播放类故障只能靠猜。与 `Global.routeLog` 同思路，
  平时保持默认日志级别、零开销

## [1.1.0](https://github.com/dinger114/xlist/releases/tag/v1.1.0) - 2026-09-22

### Changed

- 主壳由 `GetMaterialApp` 换成 `MaterialApp`（`lib/main.dart`），为引入
  material_ui 扫清唯一障碍（`GetMaterialApp.theme:` 要求 flutter 版
  `ThemeData`，与 material_ui 的同名类冲突）。GetX 的 DI / 状态 / i18n /
  导航全部保留：
  - 新增 `lib/routes/app_router.dart`：把 `AppPages.routes`（含 children
    嵌套）摊平成路由表并实现 `onGenerateRoute`，路径与迁移前逐字相同
  - 词条改为在 `main()` 里 `Get.addTranslations()` 手动注册
    （原先由 `GetMaterialApp` 内部代劳）
  - `SplashBinding().dependencies()` 手动执行（原 `initialBinding` 钩子）
  - 补 `flutter_localizations` + Global 系列 delegate
- **原计划的 go_router 迁移（约 3 周）取消**：实测裸 `MaterialApp` +
  `navigatorKey: Get.key` + `GetObserver` 下 GetX 导航、`Get.arguments`、
  binding、控制器生命周期（含 pop 时自动销毁）全部可用，53 处导航调用与
  32 处 `Get.arguments` 无需改动，也不必引入新路由库

### Bug Fixes

- 修复换成裸 `MaterialApp` 后**中文环境下弹对话框必崩**：
  `Null check operator used on a null value` → `MaterialLocalizations.of`
  → `AlertDialog.build`。根因是 `supportedLocales` 声明了 `zh_Hans` 却只挂
  `DefaultMaterialLocalizations`（仅英文），zh 解析不到 delegate 时
  `MaterialLocalizations.of()` 返回 null
- 修复换成裸 `MaterialApp` 后**所有 `Get.arguments` 为 null**（表现为点文件夹
  进详情页 `NoSuchMethodError: [](“path”) on null`）。根因是 `GetObserver`
  的**第二个**位置参数（`Get.routing`）才是被写入 `args` 的对象，漏传即
  无人写入；`GetMaterialApp` 内部传的是 `GetObserver(cb, Get.routing)`
- 修复 arguments 时序：`onGenerateRoute` 里在跑 binding **之前**写入
  `Get.routing.args`（原 GetX 在路由创建**之后**才写，而 binding 在构建时
  执行，字段初始化里读 `Get.arguments` 的 controller 会拿到 null）

### Tests

- 测试基线 117 → 150：新增 `test/routes/` 5 个文件
  - `getx_nav_shell_test.dart`：裸 shell 下 GetX 导航/参数/binding 生命周期
  - `app_router_test.dart`：路由表扁平化与匹配
  - `all_routes_reachable_test.dart`：20 条路由全量可达 + 未知路由兜底
  - `localization_delegates_test.dart`：中文下 `MaterialLocalizations` 可取
    （钉住上面那个崩溃）
  - `get_arguments_wiring_test.dart`：`Get.arguments` 接线（钉住上面那个 null）


- 移除 `floor_generator` + `json_model`，解开被钉死的 codegen 工具链
  - build_runner 2.4.13 → 2.16.1
  - flutter_gen 5.9.0 → 5.15.0
  - json_serializable 6.8.0 → 6.14.1
  - analyzer 6.x → 14.4.0（dart_style → 3.1.13）
  - `js` 0.6.7 → 0.7.2；`build_resolvers` / `build_runner_core` 从依赖树消失
- win32 组 major 升级：`device_info_plus` 13.2.0 / `file_picker` 13.1.0 /
  `package_info_plus` 10.2.1 / `share_plus` 13.3.0 / `wakelock_plus` 1.8.0 /
  `syncfusion_flutter_pdfviewer` 34.2.8
- `infinite_scroll_pagination` 4.1.0 → 5.1.1（5.x 为 API 重写，迁移了 favorite / recent 两页）
- 移除已过时的 root `build.gradle` Kotlin 兜底（改为 `state.executed` 判断，
  对子项目求值顺序不再敏感）

### Features

- 音频播放器移出路由：返回上一页不再中断播放，可后台继续
- 新增底部迷你播放条（`lib/components/mini_audio_player_bar.dart`），
  挂在 `GetMaterialApp.builder` 覆盖层，用 `Positioned` 吸附底部

### Bug Fixes

- 修复音频播放中按返回键即停止播放（根因：播放器由路由级 controller 持有，
  页面 pop 触发 `onClose()` 时被 `dispose`）
- 修复返回后通知栏 / 锁屏媒体控制失效（同上，通知栏原先指向已销毁的页面 controller）
- 修复音频页不响应「后台播放」开关（该开关此前只作用于视频页，音频页从未读取）
- 修复 `streamController` 关闭后 `updatePlaybackState` 抛未捕获异常
- 修复「播完暂停」被误当成单曲循环：抽成纯函数 `nextActionOnCompleted`，
  用 `CompletedAction` 区分「原地重播」与「停止」（原实现两者都返回 `null`）

### Breaking

- `database.g.dart` → `database.floor.dart`：floor 生成物脱离 build_runner 管理。
  改动 DB schema（entity 增删字段、加表、改 DAO 签名）时**必须手工同步该文件**，
  或临时装回 `floor_generator` 生成一次再撤掉。floor 运行时包（^1.5.0）保留。

### 备注

- 以下 5 个包**刻意保持不动**，它们的 major 升级需引入 `material_ui`：
  `get` / `cached_network_image` 3.4.1 / `flex_color_scheme` 8.4.0 /
  `flutter_smart_dialog` 4.9.8+10 / `dynamic_color` 1.9.0
- 测试：37 个用例全绿；`flutter analyze` 0 error

## [1.0.17](https://github.com/xlist-io/xlist/releases/tag/1.0.17) - 2023-10-25

- 修复安卓复制链接错误
- 安卓新增面包多支付渠道

## [1.0.16](https://github.com/xlist-io/xlist/releases/tag/1.0.16) - 2023-09-27

- 修复长按倍速问题
- 修复复制链接丢失签名参数

## [1.0.15](https://github.com/xlist-io/xlist/releases/tag/1.0.15) - 2023-09-21

- 优化图片浏览器界面
- 视频长按倍速播放

## [1.0.14](https://github.com/xlist-io/xlist/releases/tag/1.0.14) - 2023-09-08

- 全新设计的音频播放页面
- 修复若干问题和性能优化

## [1.0.13](https://github.com/xlist-io/xlist/releases/tag/1.0.13) - 2023-08-23

- 修复 https 请求证书认证问题
- 列表页允许最多两行内容显示

## [1.0.12](https://github.com/xlist-io/xlist/releases/tag/1.0.12) - 2023-08-07

- 音频记录当前播放进度
- 修改内置字幕/音轨显示名称
- 添加服务台添加提示文案

## [1.0.11](https://github.com/xlist-io/xlist/releases/tag/1.0.11) - 2023-07-30

- 优化视频播放器重试策略
- 修复若干问题和性能优化

## [1.0.10](https://github.com/xlist-io/xlist/releases/tag/1.0.10) - 2023-07-13

- 优化音视频流展示信息
- 优化页面交互问题

## [1.0.9](https://github.com/xlist-io/xlist/releases/tag/1.0.9) - 2023-07-07

- 添加通知栏播放控制器
- 删除播放音频时屏幕常量
- 修复视频切换预览图问题

## [1.0.8](https://github.com/xlist-io/xlist/releases/tag/1.0.8) - 2023-06-29

- 支持列表和网格视图切换
- 优化 pad 模式下页面展示

## [1.0.7](https://github.com/xlist-io/xlist/releases/tag/1.0.7) - 2023-06-23

- 添加硬件解码开关
- 视频播放全屏模式下支持字幕/音轨切换
- 修复 token 过期无法访问题
- 优化 pad 模式下视频播放界面
- 优化视频播放超时错误页面

## [1.0.6](https://github.com/xlist-io/xlist/releases/tag/1.0.6) - 2023-06-18

- pad 模式适配
- 修复视频播放屏幕旋转问题
- 修复播放列表无法切换音轨/字幕

## [1.0.5](https://github.com/xlist-io/xlist/releases/tag/1.0.5) - 2023-06-15

- 支持视频播放列表
- 修复若干性能问题

## 1.0.4

- 修复 2FA 验证问题
- 修复搜索错误提示

## 1.0.3

- 支持 2FA 验证
- 修复图片无法加载问题
- 优化视频播放界面

## 1.0.2

- 优化图片预览
- 修复导航 icon 问题

## 1.0.1

- 支持内置字幕解析
- 支持视频音轨切换

## 1.0.0

- 首次版本提交
- 支持文件的下载、重命名、移动和复制等功能。
- 支持 doc、docx、xls、xlsx、ppt、pptx、pdf 等格式的文件在线预览。
- 支持 mp4、mkv、avi、flv 等大部分视频的在线预览，同时支持 srt 和 vtt 字幕外挂。
- 支持 jpg、png、gif 等格式的图片在线预览。
- 文件后台下载功能，下载完成后可以用其他 App 打开预览文件。
