# Changelog

## [1.1.0](https://github.com/dinger114/xlist/releases/tag/v1.1.0) - 2026-09-22

### Dependencies

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
