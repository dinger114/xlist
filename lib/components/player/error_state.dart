import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/core/player/x_player.dart';

const double barHeight = 50.0;

class ErrorState extends StatelessWidget {
  final XPlayer player;
  final String playerTitle;
  final bool single; // 是否是单页面视频播放

  const ErrorState({
    super.key,
    required this.player,
    required this.playerTitle,
    this.single = true,
  });

  // 可以共用的架子
  Widget _buildPublicFrameWidget({required Widget slot, Color? bgColor}) {
    return Container(
      color: bgColor,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: Center(child: slot),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPublicFrameWidget(
      bgColor: Colors.black,
      slot: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 50, color: Colors.white),
                  SizedBox(height: 5),
                  ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      elevation: WidgetStateProperty.all(0),
                      backgroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                    onPressed: () {
                      // 重试当前媒体（由 Controller 提供 retryPlay）
                      try {
                        Get.find<dynamic>().retryPlay();
                      } catch (e) {
                        // 页面未注册 retryPlay 时忽略（重试按钮的兜底）
                        debugPrint('XLIST_PLAYER 重试失败: $e');
                      }
                    },
                    child: Text(
                      'player_retry'.tr,
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
