import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/models/index.dart';
import 'package:xlist/services/index.dart';
import 'package:xlist/storages/index.dart';
import 'package:xlist/constants/index.dart';
import 'package:xlist/repositorys/index.dart';
import 'package:xlist/database/entity/index.dart';

class RecentController extends GetxController {
  static const pageSize = 20;
  final isEmpty = true.obs; // 是否为空
  final serverId = Get.find<UserStorage>().serverId.val;

  /// 最近浏览数据（来自 PagingState，只读）
  List<RecentEntity> get recentList => pagingController.value.items ?? const [];

  ScrollController scrollController = ScrollController();

  /// infinite_scroll_pagination 5.x 起：分页参数改为构造函数注入，
  /// itemList/appendPage/appendLastPage/addPageRequestListener 均已移除。
  /// 这里保持原有「按 offset 分页、取到不满一页即结束」的语义。
  late final PagingController<int, RecentEntity> pagingController =
      PagingController<int, RecentEntity>(
    getNextPageKey: (state) {
      final pages = state.pages;
      // 上一页不满 pageSize，说明已到末页（与原 isLastPage 判断一致）
      if (pages != null && pages.isNotEmpty && pages.last.length < pageSize) {
        return null;
      }
      // 下一页 key = 已取条数（即 SQL offset），与原 currentIndex 语义一致
      return (pages ?? const []).fold<int>(0, (sum, p) => sum + p.length);
    },
    fetchPage: (offset) async {
      final list = await DatabaseService.to.database.recentDao
          .findRecentByServerId(serverId, pageSize, offset);
      // 判断是否为空
      if (offset == 0) isEmpty.value = list.isEmpty;
      return list;
    },
  );

  /// 删除最近浏览
  /// [entity] 最近浏览实体
  Future<void> deleteRecent(RecentEntity entity) async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      await DatabaseService.to.database.recentDao.deleteRecentById(entity.id!);
      // 5.x 的 items 是 unmodifiable，不能就地 remove，改为过滤后写回 state
      pagingController.value =
          pagingController.value.filterItems((e) => e.id != entity.id);

      isEmpty.value = recentList.isEmpty;
      SmartDialog.showToast('toast_remove_success'.tr);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 清空最近浏览
  Future<void> clearRecent() async {
    final ok = await showOkCancelAlertDialog(
      context: Get.context!,
      title: 'dialog_prompt_title'.tr,
      message: 'dialog_remove_message_all'.tr,
      okLabel: 'confirm'.tr,
      cancelLabel: 'cancel'.tr,
    );
    if (ok != OkCancelResult.ok) return;

    try {
      final id = serverId;
      await DatabaseService.to.database.recentDao.deleteRecentByServerId(id);
      await DatabaseService.to.database.progressDao
          .deleteProgressByServerId(id);

      // 清空数据：直接 reset state（等价于清空列表并回到首页）
      pagingController.refresh();

      isEmpty.value = true;
      SmartDialog.showToast('toast_remove_success_all'.tr);
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 获取对象列表
  ///
  /// [entity] 最近浏览实体
  Future<List<ObjectModel>> getObjectList(RecentEntity entity) async {
    List<ObjectModel> objects = [
      ObjectModel.fromJson({
        'name': entity.name,
        'type': entity.type,
        'is_dir': entity.type == FileType.folder,
        'size': entity.size,
      }),
    ];

    try {
      SmartDialog.showLoading();
      final sortType = Get.find<PreferencesStorage>().sortType.val;
      final response = await ObjectRepository.getList(path: entity.path);
      if (response['code'] == 200) {
        final data = FsListModel.fromJson(response['data']);
        objects = CommonUtils.sortObjectList(data.content ?? [], sortType);
      }
      SmartDialog.dismiss();
    } catch (e) {
      SmartDialog.dismiss();
    }

    return objects;
  }
}
