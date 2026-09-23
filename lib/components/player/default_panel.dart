import 'dart:math';
import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/pages/video_player/index.dart';
import 'package:xlist/components/player/slider.dart';
import 'package:xlist/components/player/error_state.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

double speed = 1.0;
const double barHeight = 50.0;

class DefaultPanel extends StatefulWidget {
  final XPlayer player;
  final String playerTitle;
  final List<Subtitle> subtitles;
  final List<String> subtitleNameList;
  final List<XTrack> audioTracks;
  final List<XTrack> subtitleTracks;
  final bool showPlaylist;
  final bool showTimedText;
  final bool isFullScreen;

  const DefaultPanel({
    super.key,
    required this.player,
    required this.playerTitle,
    required this.subtitles,
    required this.subtitleNameList,
    required this.audioTracks,
    required this.subtitleTracks,
    this.showPlaylist = false,
    this.showTimedText = true,
    this.isFullScreen = false,
  });

  @override
  State<DefaultPanel> createState() => _DefaultPanelState();
}

class _DefaultPanelState extends State<DefaultPanel>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  XPlayer get player => widget.player;
  List<Subtitle> get subtitles => widget.subtitles;
  bool get showTimedText => widget.showTimedText;

  XPlayerState? _playerState;
  Duration _currentPos = Duration.zero;

  // 是否显示各个组件
  bool _subtitleDrawerState = false;
  bool _audioDrawerState = false;

  AnimationController? _animationController;
  Animation<Offset>? _animation;

  final List<StreamSubscription> _subs = [];
  int _lastSubtitleRebuildMs = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    // init animation
    _animation = Tween(
      begin: Offset(1, 0),
      end: Offset.zero,
    ).animate(_animationController!);

    // init player state
    _playerState = player.state;
    _currentPos = player.position;

    // 监听状态
    _subs.add(
      player.stateStream.listen((state) {
        if (!mounted) return;
        setState(() => _playerState = state);
      }),
    );

    _subs.add(
      player.positionStream.listen((pos) {
        if (!mounted) return;
        _currentPos = pos;
        // 外层面板只用 position 渲染字幕：节流到 500ms，避免高频整层重绘
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSubtitleRebuildMs < 500) return;
        _lastSubtitleRebuildMs = now;
        setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _animationController!.dispose();
    super.dispose();
  }

  // 切换字幕列表显示状态
  void changeSubtitleDrawerState(bool state) {
    if (state) {
      setState(() {
        _subtitleDrawerState = state;
      });
    }
    Future.delayed(Duration(milliseconds: 100), () {
      _animationController?.forward();
    });
  }

  // 切换音轨列表显示状态
  void changeAudioDrawerState(bool state) {
    if (state) {
      setState(() {
        _audioDrawerState = state;
      });
    }
    Future.delayed(Duration(milliseconds: 100), () {
      _animationController?.forward();
    });
  }

  // 切换播放列表显示状态
  //
  // 播放列表抽屉已从本面板移除：真正在用播放列表的是
  // `pages/video_player/view.dart` 里的独立抽屉，本面板既没有渲染它，
  // 也没有任何按钮回调这里，所以连字段一起删掉，避免留下「看起来能开」的假接口。

  // 抽屉列表
  Widget _buildPublicDrawer(Widget child) {
    return Container(
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await _animationController!.reverse();
                setState(() {
                  _subtitleDrawerState = false;
                  _audioDrawerState = false;
                });
              },
            ),
          ),
          SlideTransition(
            position: _animation!,
            child: SizedBox(
              height: Get.height,
              width: 320,
              child: Scaffold(
                backgroundColor: Colors.black.withValues(alpha: 0.8),
                appBar: AppBar(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  automaticallyImplyLeading: false,
                  elevation: 0.1,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () async {
                        await _animationController!.reverse();
                        setState(() {
                          _subtitleDrawerState = false;
                          _audioDrawerState = false;
                        });
                      },
                    ),
                  ],
                ),
                body: SizedBox(height: Get.height, child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 字幕切换列表
  Widget _buildSubtitleList() {
    // 合并 subtitleNameList + subtitleTracks
    final subtitleList = List<Map<String, String>>.empty(growable: true);
    for (var v in widget.subtitleNameList) {
      subtitleList.add({'label': v, 'key': v});
    }
    for (var t in widget.subtitleTracks) {
      subtitleList.add({
        'label': '${t.displayTitle}(${t.language ?? ''})',
        'key': 'internal::${t.id}',
      });
    }

    // 添加关闭字幕
    subtitleList.add({'label': 'player_subtitle_close'.tr, 'key': 'close'});

    return ListView.separated(
      shrinkWrap: true,
      separatorBuilder: (context, index) =>
          Divider(height: 0.5, indent: 10, endIndent: 10),
      itemCount: subtitleList.length,
      itemBuilder: (context, index) {
        return CupertinoListTile(
          title: Text(
            subtitleList[index]['label'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Get.textTheme.bodyLarge?.copyWith(
              color: subtitleList[index]['key'] == 'close'
                  ? Colors.red
                  : Colors.white,
            ),
          ),
          onTap: () async {
            final value = subtitleList[index]['key'];
            final videoPlayerController = Get.find<VideoPlayerController>();
            videoPlayerController.changeSubtitle(value: value);
            await _animationController!.reverse();
            Future.delayed(Duration(milliseconds: 500), () async {
              setState(() {
                _subtitleDrawerState = false;
              });
            });
          },
        );
      },
    );
  }

  // 音轨切换列表
  Widget _buildAudioList() {
    final audioList = List<Map<String, String?>>.empty(growable: true);
    for (var t in widget.audioTracks) {
      audioList.add({
        'label': '${t.displayTitle}(${t.language ?? ''})',
        'key': t.id,
      });
    }

    return ListView.separated(
      shrinkWrap: true,
      separatorBuilder: (context, index) =>
          Divider(height: 0.5, indent: 10, endIndent: 10),
      itemCount: audioList.length,
      itemBuilder: (context, index) {
        return CupertinoListTile(
          title: Text(
            audioList[index]['label'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Get.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          onTap: () async {
            final value = audioList[index]['key'];
            final videoPlayerController = Get.find<VideoPlayerController>();
            videoPlayerController.changeAudioTrack(value: value);
            await _animationController!.reverse();
            Future.delayed(Duration(milliseconds: 500), () async {
              setState(() {
                _audioDrawerState = false;
              });
            });
          },
        );
      },
    );
  }

  // 字幕
  Widget _buildSubtitle() {
    // 外挂的字幕
    final subtitle = subtitles.firstWhereOrNull(
      (s) => _currentPos >= s.startTime && _currentPos <= s.endTime,
    );
    final timedText = (subtitle != null && !showTimedText) ? subtitle.text : '';

    // 字幕样式
    final style = widget.isFullScreen || CommonUtils.isPad
        ? Get.textTheme.titleLarge
        : Get.textTheme.bodySmall;

    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.isFullScreen ? 10 : 5,
      child: Center(
        child: Text(
          timedText,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: style?.copyWith(
            color: Colors.white,
            height: 1.3,
            fontFamily: 'PingFang SC',
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin

    List<Widget> ws = [];

    if (_playerState == XPlayerState.error) {
      ws.add(
        ErrorState(player: widget.player, playerTitle: widget.playerTitle),
      );
    } else {
      ws.add(_buildSubtitle()); // 字幕

      // 抽屉组件 & 手势组件
      if (_subtitleDrawerState == true && widget.isFullScreen) {
        ws.add(_buildPublicDrawer(_buildSubtitleList()));
      } else if (_audioDrawerState == true && widget.isFullScreen) {
        ws.add(_buildPublicDrawer(_buildAudioList()));
      } else {
        ws.add(
          _GestureDetector(
            player: widget.player,
            playerTitle: widget.playerTitle,
            showNextEpisodeBtn: widget.showPlaylist,
            showSubtitleDrawerBtn:
                widget.subtitleNameList.isNotEmpty ||
                widget.subtitleTracks.isNotEmpty,
            showAudioDrawerBtn: widget.audioTracks.length > 1,
            isFullScreen: widget.isFullScreen,
            changeSubtitleDrawerState: changeSubtitleDrawerState,
            changeAudioDrawerState: changeAudioDrawerState,
          ),
        );
      }
    }

    // 注意：**不能**返回 `Positioned.fill`。
    //
    // 调用处（`pages/video_player/view.dart`）是
    //   Stack > Positioned.fill > Obx > DefaultPanel
    // 中间隔了一层 `Obx`，而 `Positioned` 的父级必须**直接**是 `Stack`
    // （由 `ParentDataWidget` 的 `debugIsValidRenderObject` 断言）。隔了 Obx 后
    // ParentData 落到了 `Scaffold` 的 `CustomMultiChildLayout` 上，类型不匹配：
    //   Incorrect use of ParentDataWidget. ... wants to apply ParentData of type
    //   StackParentData to a RenderObject ... incompatible type
    //   MultiChildLayoutParentData
    // debug 下是红屏 + 断言；**release 下 Flutter 的 ErrorWidget 是个灰色方块**，
    // 于是表现为「底部控制栏变灰块、音量/亮度手势失效」。
    // 铺满由调用处的 `Positioned.fill` 负责，这里只返回 `Stack`。
    // 必须包一层 `Material`。
    //
    // 下面 `_GestureDetector` 里多处用了 `Ink`/`InkWell`（播放按钮、倍速、
    // 手势层的按钮），而 `Ink` 会 `Material.of(context)`；页面根是
    // `CupertinoPageScaffold`，**不提供 `Material` 祖先**。
    //
    // 迁移前没有问题：面板由 fijk 的 `panelBuilder` 提供，fijk 的 view/panel
    // 内部自带 `Material`。media_kit 迁移后改成自己 `Stack` 挂 `DefaultPanel`，
    // 这层祖先就丢了。
    //
    // 失败表现：`Material.of` 末尾是 `return controller!`，而那句会给人看原因的
    // assert 在 release 被剥离 → 只报裸的
    //   Null check operator used on a null value
    // 面板**每秒重建一次**（播放位置 ticker），于是每帧抛一次；`Ink` 所在的
    // 底部控制栏渲染成灰块（release 的 ErrorWidget），手势层一并失效。
    //
    // `MaterialType.transparency`：提供 ink controller 但不画任何底色 ——
    // 播放器上必须透明，否则会盖住视频画面。
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: ws),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _GestureDetector extends StatefulWidget {
  final XPlayer player;
  final String playerTitle;
  final bool showNextEpisodeBtn;
  final bool showSubtitleDrawerBtn;
  final bool showAudioDrawerBtn;
  final bool isFullScreen;
  final Function changeSubtitleDrawerState;
  final Function changeAudioDrawerState;

  const _GestureDetector({
    this.playerTitle = "",
    required this.player,
    required this.showNextEpisodeBtn,
    required this.showSubtitleDrawerBtn,
    required this.showAudioDrawerBtn,
    required this.isFullScreen,
    required this.changeSubtitleDrawerState,
    required this.changeAudioDrawerState,
  });

  @override
  _GestureDetectorState createState() => _GestureDetectorState();
}

class _GestureDetectorState extends State<_GestureDetector> {
  XPlayer get player => widget.player;

  Duration _duration = Duration();
  Duration _currentPos = Duration();
  Duration _bufferPos = Duration();

  // 滑动后值
  Duration _dargPos = Duration();

  bool _isTouch = false;

  bool _playing = false;
  bool _prepared = false;

  double? updatePrevDx;
  double? updatePrevDy;
  int? updatePosX;

  bool? isDargVerLeft;

  double? updateDargVarVal;

  bool varTouchInitSuc = false;

  bool _buffering = false;

  double _seekPos = -1.0;

  StreamSubscription? _positionSubs;
  StreamSubscription? _bufferSubs;
  StreamSubscription? _bufferingSubs;
  StreamSubscription? _durationSubs;
  StreamSubscription? _playingSubs;

  Timer? _hideTimer;
  bool _hideStuff = true;

  /// UI 隐藏时驱动吸底进度条的最小化重建
  final ValueNotifier<double> bottomProgress = ValueNotifier<double>(0);

  bool _hideSpeedStu = true;
  double _speed = speed;

  bool _isHorizontalMove = false;

  Map<String, double> speedList = {
    "2.0": 2.0,
    "1.8": 1.8,
    "1.5": 1.5,
    "1.2": 1.2,
    "1.0": 1.0,
  };

  // 初始化构造函数
  _GestureDetectorState();

  void initEvent() {
    _duration = player.duration;
    _currentPos = player.position;
    _bufferPos = player.buffer;
    _prepared =
        player.state != XPlayerState.idle &&
        player.state != XPlayerState.loading;
    _playing = player.isPlaying;
    _buffering = player.isBuffering;

    // 设置初始化的值，全屏与半屏切换后，重设
    setState(() {
      // 每次重绘的时候，判断是否已经开始播放
      _hideStuff = !_playing ? false : true;
    });
    // 延时隐藏
    _startHideTimer();
  }

  @override
  void dispose() {
    super.dispose();
    _hideTimer?.cancel();
    bottomProgress.dispose();

    _positionSubs?.cancel();
    _bufferSubs?.cancel();
    _bufferingSubs?.cancel();
    _durationSubs?.cancel();
    _playingSubs?.cancel();
  }

  @override
  void initState() {
    super.initState();

    initEvent();

    _positionSubs = player.positionStream.listen((v) {
      if (!mounted) return;
      // 位置流高频触发：只在 UI 可见或拖动中才重绘整个面板，
      // UI 隐藏时静默更新值，吸底进度条由独立的 ValueListenable 驱动。
      _currentPos = v;
      if (!_prepared) _prepared = true;
      if (!_playing) _playing = true;
      if (!_hideStuff || _isHorizontalMove) {
        setState(() {});
      } else {
        bottomProgress.value = v.inMilliseconds.toDouble();
      }
    });

    _bufferSubs = player.bufferStream.listen((v) {
      if (!mounted) return;
      _bufferPos = v;
      if (_hideStuff && !_isHorizontalMove) return; // UI 隐藏时无需重绘
      setState(() {});
    });

    _bufferingSubs = player.bufferingStream.listen((v) {
      if (!mounted) return;
      setState(() {
        _buffering = v;
      });
    });

    _durationSubs = player.durationStream.listen((v) {
      if (!mounted) return;
      setState(() {
        _duration = v;
      });
    });

    _playingSubs = player.playingStream.listen((v) {
      if (!mounted) return;
      setState(() {
        _playing = v;
      });
    });
  }

  /// 长按屏幕快进
  ///
  /// [detills] 事件
  void _onLongPressStart(LongPressStartDetails detills) {
    player.setRate(_speed * 3.0);
    setState(() {
      _hideTimer?.cancel();
      _hideStuff = false;
      _hideSpeedStu = true;
    });
  }

  void _onLongPressEnd(LongPressEndDetails detills) {
    player.setRate(_speed);
    setState(() {
      _hideStuff = true;
      _hideSpeedStu = true;
    });
  }

  void _onHorizontalDragStart(DragStartDetails detills) {
    setState(() {
      updatePrevDx = detills.globalPosition.dx;
      updatePosX = _currentPos.inMilliseconds;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails detills) {
    double curDragDx = detills.globalPosition.dx;
    // 确定当前是前进或者后退
    int cdx = curDragDx.toInt();
    int pdx = updatePrevDx!.toInt();
    bool isBefore = cdx > pdx;

    // 计算手指滑动的比例
    int newInterval = pdx - cdx;
    double playerW = MediaQuery.of(context).size.width;
    int curIntervalAbs = newInterval.abs();
    double movePropCheck = (curIntervalAbs / playerW) * 100 * 0.3;

    // 计算进度条的比例
    double durProgCheck = _duration.inMilliseconds.toDouble() / 100;
    int checkTransfrom = (movePropCheck * durProgCheck).toInt();
    int dragRange = isBefore
        ? updatePosX! + checkTransfrom
        : updatePosX! - checkTransfrom;

    // 是否溢出 最大
    int lastSecond = _duration.inMilliseconds;
    if (dragRange >= _duration.inMilliseconds) {
      dragRange = lastSecond;
    }
    // 是否溢出 最小
    if (dragRange <= 0) {
      dragRange = 0;
    }
    //
    setState(() {
      _isHorizontalMove = true;
      _hideStuff = false;
      _isTouch = true;
      // 更新下上一次存的滑动位置
      updatePrevDx = curDragDx;
      // 更新时间
      updatePosX = dragRange.toInt();
      _dargPos = Duration(milliseconds: updatePosX!.toInt());
    });
  }

  void _onHorizontalDragEnd(DragEndDetails detills) {
    if (_duration.inMilliseconds != 0) {
      player.seek(Duration(milliseconds: _dargPos.inMilliseconds));
    }
    setState(() {
      _isHorizontalMove = false;
      _isTouch = false;
      _hideStuff = true;
      _currentPos = _dargPos;
    });
  }

  Future<void> _onVerticalDragStart(DragStartDetails detills) async {
    double clientW = MediaQuery.of(context).size.width;
    double curTouchPosX = detills.globalPosition.dx;

    setState(() {
      // 更新位置
      updatePrevDy = detills.globalPosition.dy;
      // 是否左边
      isDargVerLeft = (curTouchPosX > (clientW / 2)) ? false : true;
    });

    // 右半屏 = 音量，左半屏 = 亮度（沿用 fijk 面板的约定）。
    // 必须读**当前**值作为基准：media_kit 迁移时这里被写死成 1.0，
    // 于是一上手就跳满，来回滑还会反复弹到两端。
    try {
      if (!isDargVerLeft!) {
        final v = await SystemUiHelper.getVolume();
        if (!mounted) return;
        setState(() {
          varTouchInitSuc = true;
          updateDargVarVal = v;
        });
      } else {
        final v = await SystemUiHelper.getBrightness();
        if (!mounted) return;
        setState(() {
          varTouchInitSuc = true;
          updateDargVarVal = v;
        });
      }
    } catch (e) {
      // 通道异常（如非 Android 平台）时退回默认值，不能让手势整体失效；
      // 但要留下痕迹，否则「滑了没反应」无从排查。
      debugPrint('XLIST_GESTURE 读取当前值失败: $e');
      if (!mounted) return;
      setState(() {
        varTouchInitSuc = true;
        updateDargVarVal = 1.0;
      });
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails detills) {
    if (!varTouchInitSuc) return;
    double curDragDy = detills.globalPosition.dy;
    // 确定当前是前进或者后退
    int cdy = curDragDy.toInt();
    int pdy = updatePrevDy!.toInt();
    bool isBefore = cdy < pdy;
    // + -, 不满足, 上下滑动合法滑动值，> 3
    if (isBefore && pdy - cdy < 3 || !isBefore && cdy - pdy < 3) return;
    // 区间
    double dragRange = isBefore
        ? updateDargVarVal! + 0.03
        : updateDargVarVal! - 0.03;
    // 是否溢出
    if (dragRange > 1) {
      dragRange = 1.0;
    }
    if (dragRange < 0) {
      dragRange = 0.0;
    }
    setState(() {
      updatePrevDy = curDragDy;
      varTouchInitSuc = true;
      updateDargVarVal = dragRange;
      // 右半屏 → 系统音量；左半屏 → 屏幕亮度。
      // 亮度的 else 分支在 media_kit 迁移时被整段删掉了（fijk 的
      // FijkPlugin.setScreenBrightness 随插件一起移除且未替代），
      // 所以左半屏上下滑此前完全无反应。
      if (!isDargVerLeft!) {
        SystemUiHelper.setVolume(dragRange);
      } else {
        SystemUiHelper.setBrightness(dragRange);
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails detills) {
    setState(() {
      varTouchInitSuc = false;
    });
  }

  void _playOrPause() {
    if (_playing == true) {
      player.pause();
    } else {
      player.play();
    }
  }

  void _cancelAndRestartTimer() {
    if (_hideStuff == true) {
      _startHideTimer();
    }

    setState(() {
      _hideStuff = !_hideStuff;
      if (_hideStuff == true) {
        _hideSpeedStu = true;
      } else {
        // UI 重新可见，恢复整面板重绘路径
        bottomProgress.value = _currentPos.inMilliseconds.toDouble();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _hideStuff = true;
        _hideSpeedStu = true;
      });
      bottomProgress.value = _currentPos.inMilliseconds.toDouble();
    });
  }

  // 底部控制栏 - 播放按钮
  Widget _buildPlayStateBtn(IconData iconData, Function cb) {
    return Ink(
      child: InkWell(
        onTap: () => cb(),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: EdgeInsets.only(left: 5, right: 5),
            child: Icon(iconData, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // 控制器ui 底部
  Widget _buildBottomBar(BuildContext context) {
    // 计算进度时间
    double duration = _duration.inMilliseconds.toDouble();
    double currentValue = _seekPos > 0
        ? _seekPos
        : (_isHorizontalMove
              ? _dargPos.inMilliseconds.toDouble()
              : _currentPos.inMilliseconds.toDouble());
    currentValue = min(currentValue, duration);
    currentValue = max(currentValue, 0);

    // 计算缓存进度
    double cacheValue = _bufferPos.inMilliseconds.toDouble();
    cacheValue = min(cacheValue, duration);
    cacheValue = max(cacheValue, 0);

    return SizedBox(
      height: barHeight,
      child: Stack(
        children: [
          // 底部UI控制器
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _hideStuff ? 0.0 : 0.8,
              duration: Duration(milliseconds: 400),
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color.fromRGBO(0, 0, 0, 0),
                      Color.fromRGBO(0, 0, 0, 0.4),
                    ],
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 7),
                    // 按钮 - 播放/暂停
                    _buildPlayStateBtn(
                      _playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      _playOrPause,
                    ),
                    // 已播放时间
                    Padding(
                      padding: EdgeInsets.only(right: 5.0, left: 5),
                      child: Text(
                        PlayerHelper.formatDuration(_currentPos),
                        style: TextStyle(fontSize: 14.0, color: Colors.white),
                      ),
                    ),
                    // 播放进度
                    _duration.inMilliseconds == 0
                        ? Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 5, left: 5),
                              child: XSlider(
                                colors: XSliderColors(
                                  cursorColor: Get.theme.primaryColor,
                                  playedColor: Get.theme.primaryColor,
                                ),
                                onChangeEnd: (double value) {},
                                value: 0,
                                onChanged: (double value) {},
                              ),
                            ),
                          )
                        : Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 5, left: 5),
                              child: XSlider(
                                colors: XSliderColors(
                                  cursorColor: Get.theme.primaryColor,
                                  playedColor: Get.theme.primaryColor,
                                ),
                                value: currentValue,
                                cacheValue: cacheValue,
                                min: 0.0,
                                max: duration,
                                onChanged: (v) {
                                  _startHideTimer();
                                  setState(() {
                                    _seekPos = v;
                                  });
                                },
                                onChangeEnd: (v) {
                                  setState(() {
                                    player.seek(
                                      Duration(milliseconds: v.toInt()),
                                    );
                                    _currentPos = Duration(
                                      milliseconds: v.toInt(),
                                    );
                                    _seekPos = -1;
                                  });
                                },
                              ),
                            ),
                          ),
                    // 总播放时间
                    _duration.inMilliseconds == 0
                        ? const Text(
                            "00:00",
                            style: TextStyle(color: Colors.white),
                          )
                        : Padding(
                            padding: EdgeInsets.only(right: 5.0, left: 5),
                            child: Text(
                              PlayerHelper.formatDuration(_duration),
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    // 切换字幕按钮
                    widget.isFullScreen && widget.showSubtitleDrawerBtn
                        ? Ink(
                            padding: EdgeInsets.all(5),
                            child: InkWell(
                              onTap: () {
                                widget.changeSubtitleDrawerState(true);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: 40,
                                height: 30,
                                child: Text(
                                  'player_subtitle'.tr,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Container(),
                    // 切换音轨按钮
                    widget.isFullScreen && widget.showAudioDrawerBtn
                        ? Ink(
                            padding: EdgeInsets.all(5),
                            child: InkWell(
                              onTap: () {
                                widget.changeAudioDrawerState(true);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: 40,
                                height: 30,
                                child: Text(
                                  'player_audio_track'.tr,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Container(),
                    // 下一集
                    widget.showNextEpisodeBtn && widget.isFullScreen
                        ? Ink(
                            padding: EdgeInsets.all(5),
                            child: InkWell(
                              onTap: () {
                                final vp = Get.find<VideoPlayerController>();
                                vp.currentIndex.value == vp.objects.length - 1
                                    ? vp.changePlaylist(0)
                                    : vp.changePlaylist(
                                        vp.currentIndex.value + 1,
                                      );
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: 45,
                                height: 30,
                                child: Text(
                                  'player_next'.tr,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Container(),
                    // 倍数按钮
                    widget.isFullScreen
                        ? Ink(
                            padding: EdgeInsets.all(5),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _hideSpeedStu = !_hideSpeedStu;
                                });
                              },
                              child: Container(
                                alignment: Alignment.center,
                                width: 40,
                                height: 30,
                                child: Text(
                                  "$_speed X",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Container(),
                    // 按钮 - 画中画
                    _buildPlayStateBtn(Icons.picture_in_picture_alt, () async {
                      final ok = await PipHelper.enterPip();
                      if (!ok && mounted) {
                        SmartDialog.showToast('toast_pip_fail'.tr);
                      }
                    }),
                    // 按钮 - 全屏/退出全屏
                    _buildPlayStateBtn(Icons.fullscreen, () {
                      final vp = Get.find<VideoPlayerController>();
                      vp.toggleFullScreen();
                    }),
                    SizedBox(width: 7),
                    //
                  ],
                ),
              ),
            ),
          ),
          // 隐藏进度条，ui隐藏时出现（ValueListenableBuilder 驱动，避免整面板重绘）
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child:
                (_hideStuff &&
                    _duration.inMilliseconds != 0 &&
                    !widget.isFullScreen)
                ? Container(
                    alignment: Alignment.bottomLeft,
                    height: 1.5,
                    color: Colors.transparent,
                    child: ValueListenableBuilder<double>(
                      valueListenable: bottomProgress,
                      builder: (context, posMs, _) {
                        final ratio = _duration.inMilliseconds == 0
                            ? 0.0
                            : (posMs / _duration.inMilliseconds).clamp(
                                0.0,
                                1.0,
                              );
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            color: Get.theme.primaryColor,
                            height: 1.5,
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }

  // 返回按钮
  Widget _buildTopBackBtn() {
    return IconButton(
      icon: Icon(CupertinoIcons.chevron_back),
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      color: Colors.white,
      onPressed: () => Get.back(),
    );
  }

  // 播放器顶部 返回 + 标题
  Widget _buildTopBar() {
    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 0.8,
      duration: Duration(milliseconds: 400),
      child: Container(
        height: barHeight,
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [Color.fromRGBO(0, 0, 0, 0.5), Color.fromRGBO(0, 0, 0, 0)],
          ),
        ),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: <Widget>[
              _buildTopBackBtn(),
              Expanded(
                child: Text(
                  widget.playerTitle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 居中播放按钮
  Widget _buildCenterPlayBtn() {
    return Container(
      color: Colors.transparent,
      height: double.infinity,
      width: double.infinity,
      child: Center(
        child: (_prepared && !_buffering)
            ? AnimatedOpacity(
                opacity: _hideStuff ? 0.0 : 0.7,
                duration: Duration(milliseconds: 400),
                child: GestureDetector(
                  onTap: _playOrPause,
                  child: Container(
                    height: 50.0,
                    width: 50.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[800]?.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: Icon(
                      _playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 30.0,
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: barHeight * (widget.isFullScreen ? 0.6 : 0.5),
                    height: barHeight * (widget.isFullScreen ? 0.6 : 0.5),
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // build 滑动进度时间显示
  Widget _buildDargProgressTime() {
    return _isTouch
        ? Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              color: Color.fromRGBO(0, 0, 0, 0.8),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 10, right: 10),
              child: Text(
                '${PlayerHelper.formatDuration(_dargPos)} / ${PlayerHelper.formatDuration(_duration)}',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          )
        : Container();
  }

  // build 显示垂直亮度，音量
  Widget _buildDargVolumeAndBrightness() {
    // 不显示
    if (!varTouchInitSuc) return Container();

    IconData iconData;
    // 判断当前值范围，显示的图标
    if (updateDargVarVal! <= 0) {
      iconData = !isDargVerLeft!
          ? CupertinoIcons.volume_mute
          : CupertinoIcons.brightness_solid;
    } else if (updateDargVarVal! < 0.5) {
      iconData = !isDargVerLeft!
          ? CupertinoIcons.volume_down
          : CupertinoIcons.brightness_solid;
    } else {
      iconData = !isDargVerLeft!
          ? CupertinoIcons.volume_up
          : CupertinoIcons.brightness_solid;
    }
    // 显示，亮度 || 音量
    return Card(
      color: Color.fromRGBO(0, 0, 0, 0.8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(iconData, color: Colors.white),
            Container(
              width: 100,
              height: 3,
              margin: EdgeInsets.only(left: 8),
              child: LinearProgressIndicator(
                value: updateDargVarVal,
                backgroundColor: Colors.white54,
                valueColor: AlwaysStoppedAnimation(Get.theme.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // build 倍数列表
  List<Widget> _buildSpeedListWidget() {
    List<Widget> columnChild = [];
    speedList.forEach((String mapKey, double speedVals) {
      columnChild.add(
        Ink(
          child: InkWell(
            onTap: () {
              if (_speed == speedVals) return;
              setState(() {
                _speed = speed = speedVals;
                _hideSpeedStu = true;
                player.setRate(speedVals);
              });
            },
            child: Container(
              alignment: Alignment.center,
              width: 50,
              height: 30,
              child: Text(
                "$mapKey X",
                style: TextStyle(
                  color: _speed == speedVals
                      ? Get.theme.primaryColor
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
      columnChild.add(
        Padding(
          padding: EdgeInsets.only(top: 5, bottom: 5),
          child: Container(width: 50, height: 1, color: Colors.white54),
        ),
      );
    });
    columnChild.removeAt(columnChild.length - 1);
    return columnChild;
  }

  // 播放器控制器 ui
  Widget _buildGestureDetector() {
    return GestureDetector(
      onTap: _cancelAndRestartTimer,
      onDoubleTap: _playOrPause,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AbsorbPointer(
        absorbing: _hideStuff,
        child: Column(
          children: <Widget>[
            // 播放器顶部控制器
            widget.isFullScreen ? _buildTopBar() : SizedBox(),
            // 中间按钮
            Expanded(
              child: Stack(
                children: <Widget>[
                  // 顶部显示
                  Positioned(
                    top: widget.isFullScreen ? 20 : 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 显示左右滑动快进时间的块
                        _buildDargProgressTime(),
                        // 显示上下滑动音量亮度
                        _buildDargVolumeAndBrightness(),
                      ],
                    ),
                  ),
                  // 中间按钮
                  Align(
                    alignment: Alignment.center,
                    child: _buildCenterPlayBtn(),
                  ),
                  // 倍数选择
                  Positioned(
                    right: 35,
                    bottom: 0,
                    child: !_hideSpeedStu
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Column(children: _buildSpeedListWidget()),
                            ),
                          )
                        : Container(),
                  ),
                ],
              ),
            ),
            // 播放器底部控制器
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildGestureDetector();
  }
}
