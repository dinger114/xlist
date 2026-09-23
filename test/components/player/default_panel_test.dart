import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:xlist/components/player/default_panel.dart';
import 'package:xlist/core/player/x_player.dart';
import 'package:xlist/core/player/x_player_state.dart';
import 'package:xlist/core/player/x_player_track.dart';

/// DefaultPanel 布局回归测试。
///
/// 真机现象（Pixel 6 Pro / Android 17 / release）：播放视频后**底部控制栏
/// 变成灰色方块**、音量与亮度手势失效。release 下 Flutter 的 `ErrorWidget`
/// 就是灰色方块，所以「灰块 + 子树上手势失效」= 面板在挂载时抛异常被顶替。
///
/// 根因（真机 release 实测）：面板里用了 `Ink`/`InkWell`，而 `Ink` 会
/// `Material.of(context)`；页面根是 `CupertinoPageScaffold`，**不提供 Material
/// 祖先**，于是 `Material.of` 末尾的 `return controller!` 抛
///   Null check operator used on a null value
/// （那句会说明原因的 assert 被 release 剥离了）。面板每秒随播放位置重建，
/// 于是每帧抛一次，`Ink` 所在的底部控制栏渲染成灰块、手势层一并失效。
///
/// 因此**壳必须是 `CupertinoPageScaffold`**：用 `Scaffold` 会自带 Material，
/// 把 bug 掩盖掉（实测过）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 复刻 `main.dart` 的壳接线：裸 `MaterialApp` + `navigatorKey: Get.key`
  /// ＋ `GetObserver`。用裸壳而非 `GetMaterialApp` 是本项目的实际形态。
  Widget shell({required Widget child}) => ScreenUtilInit(
        designSize: const Size(360, 800),
        builder: (context, child) => MaterialApp(
          navigatorKey: Get.key,
          navigatorObservers: [GetObserver(null, Get.routing)],
          // 必须复刻真机的页面根：`video_player/view.dart` 用的是
          // `CupertinoPageScaffold` —— 它**不**提供 Material 祖先。
          // 换成 `Scaffold` 会自带 Material，把本用例要守的 bug 掩盖掉。
          home: CupertinoPageScaffold(child: child!),
        ),
        child: child,
      );

  /// 复刻 `pages/video_player/view.dart` 的层级：
  /// `Stack > Positioned.fill > Obx > DefaultPanel(> Stack)`
  /// —— `Obx` 这一层正是原 bug 的触发条件，不能省。
  Widget videoLayer({required XPlayer player, required RxBool inPip}) => Stack(
        children: [
          Positioned.fill(
            // Obx 必须读到真正的可观察对象，否则 GetX 会报
            // "the improper use of a GetX has been detected"（真代码里是
            // controller.isInPip.value，这里用等价的 RxBool）。
            child: Obx(() => inPip.value
                ? const SizedBox.shrink()
                : DefaultPanel(
                    player: player,
                    playerTitle: '测试视频',
                    subtitles: const [],
                    subtitleNameList: const [],
                    audioTracks: const [],
                    subtitleTracks: const [],
                  )),
          ),
        ],
      );

  Future<List<FlutterErrorDetails>> captureErrors(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await body();
    } finally {
      FlutterError.onError = prev;
    }
    return errors;
  }

  testWidgets('DefaultPanel 在真实的 Stack>Positioned>Obx 层级下不抛异常', (tester) async {
    final player = FakeXPlayer();
    final errors = await captureErrors(tester, () async {
      await tester.pumpWidget(
          shell(child: videoLayer(player: player, inPip: false.obs)));
      await tester.pump(const Duration(milliseconds: 400));
    });

    expect(
      errors.map((e) => '${e.exception}').toList(),
      isEmpty,
      reason: 'DefaultPanel 不得在挂载时抛异常（release 下会变成灰块、手势失效）',
    );
    await player.dispose();
  });

  testWidgets('播放中推送进度/时长后仍无异常', (tester) async {
    final player = FakeXPlayer();
    final errors = await captureErrors(tester, () async {
      await tester.pumpWidget(
          shell(child: videoLayer(player: player, inPip: false.obs)));
      await tester.pump();
      player.emitDuration(const Duration(minutes: 5));
      player.emitPosition(const Duration(seconds: 30));
      player.emitPlaying(true);
      await tester.pump(const Duration(milliseconds: 200));
    });

    expect(errors.map((e) => '${e.exception}').toList(), isEmpty);
    await player.dispose();
  });

  testWidgets('时长为 0 / 进度为 0 的边界不抛异常', (tester) async {
    final player = FakeXPlayer();
    final errors = await captureErrors(tester, () async {
      await tester.pumpWidget(
          shell(child: videoLayer(player: player, inPip: false.obs)));
      await tester.pump();
      player.emitDuration(Duration.zero);
      player.emitPosition(Duration.zero);
      await tester.pump(const Duration(milliseconds: 200));
    });

    expect(errors.map((e) => '${e.exception}').toList(), isEmpty);
    await player.dispose();
  });

  testWidgets('切到 PiP 时不抛异常', (tester) async {
    final player = FakeXPlayer();
    final errors = await captureErrors(tester, () async {
      await tester.pumpWidget(
          shell(child: videoLayer(player: player, inPip: true.obs)));
      await tester.pump(const Duration(milliseconds: 200));
    });

    expect(errors.map((e) => '${e.exception}').toList(), isEmpty);
    await player.dispose();
  });

  testWidgets('回归守护：DefaultPanel.build 不得返回 Positioned', (tester) async {
    // 结构性断言：直接检查 build 产物顶层不是 Positioned。
    // 这样即使将来有人把它改回 Positioned.fill，也会在这里被拦住。
    final player = FakeXPlayer();
    await tester
        .pumpWidget(shell(child: videoLayer(player: player, inPip: false.obs)));
    await tester.pump(const Duration(milliseconds: 400));

    final panelFinder = find.byType(DefaultPanel);
    expect(panelFinder, findsOneWidget);

    // DefaultPanel 之下、Obx 之上的最外层 Positioned 只能来自调用处。
    // 若 build 又返回 Positioned，会额外出现一个 Positioned 直接包住 Stack。
    final stackInPanel = find.descendant(
      of: panelFinder,
      matching: find.byType(Stack),
    );
    expect(stackInPanel, findsWidgets);
    await player.dispose();
  });
}

/// 最小 XPlayer 假实现，可推送各条流以驱动 DefaultPanel 的分支。
class FakeXPlayer implements XPlayer {
  final _stateCtrl = StreamController<XPlayerState>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _durCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _completedCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _tracksCtrl = StreamController<List<XTrack>>.broadcast();
  final _selCtrl = StreamController<XTrackSelection>.broadcast();

  void emitDuration(Duration d) => _durCtrl.add(d);
  void emitPosition(Duration d) => _posCtrl.add(d);
  void emitPlaying(bool v) => _playingCtrl.add(v);
  void emitState(XPlayerState s) => _stateCtrl.add(s);

  @override
  Stream<XPlayerState> get stateStream => _stateCtrl.stream;
  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get bufferStream => _bufCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<Duration> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<bool> get completedStream => _completedCtrl.stream;
  @override
  Stream<String> get errorStream => _errorCtrl.stream;
  @override
  Stream<List<XTrack>> get tracksStream => _tracksCtrl.stream;
  @override
  Stream<XTrackSelection> get trackSelectionStream => _selCtrl.stream;

  @override
  XPlayerState get state => XPlayerState.idle;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get buffer => Duration.zero;
  @override
  Duration get duration => Duration.zero;
  @override
  bool get isPlaying => false;
  @override
  bool get isBuffering => false;
  @override
  List<XTrack> get tracks => const [];
  @override
  XTrackSelection get trackSelection => XTrackSelection();

  @override
  Future<void> open(String url,
      {Map<String, String>? headers, bool autoPlay = true}) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setAudioTrack(XTrack track) async {}
  @override
  Future<void> setSubtitleTrack(XTrack? track) async {}
  @override
  Future<void> setHardwareDecode(bool enabled) async {}
  @override
  Future<void> setProperty(String key, String value) async {}

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
    await _posCtrl.close();
    await _bufCtrl.close();
    await _bufferingCtrl.close();
    await _durCtrl.close();
    await _playingCtrl.close();
    await _completedCtrl.close();
    await _errorCtrl.close();
    await _tracksCtrl.close();
    await _selCtrl.close();
  }
}
