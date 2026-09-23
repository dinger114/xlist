import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:xlist/common/index.dart';
import 'package:xlist/helper/index.dart';
import 'package:xlist/components/markdown_style.dart';
import 'package:xlist/pages/document/index.dart';

class DocumentPage extends GetView<DocumentController> {
  const DocumentPage({Key? key}) : super(key: key);

  // NavigationBar
  CupertinoNavigationBar _buildNavigationBar() {
    List<PullDownMenuEntry> items = [];

    // 收藏
    items.add(PullDownMenuItem(
      title: 'favorite'.tr,
      onTap: () => controller.favorite(),
    ));

    return CupertinoNavigationBar(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      border: Border.all(width: 0, color: Colors.transparent),
      leading: CommonUtils.backButton,
      middle: Text(
        CommonUtils.formatFileNme(controller.name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PullDownButton(
        itemBuilder: (context) => [
          ...items,
          PullDownMenuItem(
            title: 'pull_down_copy_link'.tr,
            onTap: () => controller.copyLink(),
          ),
          PullDownMenuItem(
            title: 'pull_down_download_file'.tr,
            onTap: () => controller.download(),
          ),
        ],
        buttonBuilder: (context, showMenu) => CupertinoButton(
          onPressed: showMenu,
          padding: EdgeInsets.zero,
          alignment: Alignment.centerRight,
          child: Icon(
            CupertinoIcons.ellipsis_circle,
            size: CommonUtils.navIconSize,
          ),
        ),
      ),
    );
  }

  // WebView
  Widget _buildInAppWebView() {
    return InAppWebView(
      key: controller.webViewKey,
      initialUrlRequest: URLRequest(
        url: WebUri(controller.object.value.rawUrl ?? ''),
        headers: controller.httpHeaders,
      ),
      initialOptions: controller.options,
      onProgressChanged: controller.onProgressChanged,
      onReceivedServerTrustAuthRequest: (app, challenge) async {
        return ServerTrustAuthResponse(
          action: ServerTrustAuthResponseAction.PROCEED,
        );
      },
      androidOnPermissionRequest: (app, origin, resources) async {
        return PermissionRequestResponse(
          resources: resources,
          action: PermissionRequestResponseAction.GRANT,
        );
      },
      shouldOverrideUrlLoading: (app, navigationAction) async {
        final uri = navigationAction.request.url!;

        /// 过滤掉不需要跳转的链接
        if (!['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about']
            .contains(uri.scheme)) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            return NavigationActionPolicy.CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  // PDF
  Widget _buildPdfView() {
    return Container(
      child: SfPdfViewer.network(
        controller.object.value.rawUrl ?? '',
        headers: controller.httpHeaders.value,
        canShowScrollHead: true,
        canShowPaginationDialog: false,
        canShowPasswordDialog: false,
        canShowHyperlinkDialog: false,
        enableDoubleTapZooming: false,
      ),
    );
  }

  // Markdown 渲染
  //
  // 注意：`md` 同时出现在 `kSupportPreviewCodeTypes`（被 `PreviewHelper.isCode`
  // 命中）和 `kCodeLanguages` 里，历史上 md 走的是「代码高亮」分支 ——
  // `'markdown'` 是 highlight.js 的**语法名**，不是渲染器，所以用户看到的是
  // 源码文本而非排版后的文档。这里单独为 md 走真正的渲染。
  Widget _buildMarkdownView() {
    final text = controller.codeText.value;
    return Markdown(
      data: text,
      selectable: true,
      padding: EdgeInsets.all(16.r),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.parse(href);
        // 与下方 WebView 的处理保持一致：先 canLaunchUrl 再 launch。
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      // 排版细节集中在 MarkdownStyles 里（含为何不用 fromTheme 默认值的说明）：
      // 默认值把所有 *Padding 都设为 zero，标题与段落会挤成一团。
      // 尺寸全部用逻辑像素：本项目的 ScreenUtil designSize 与设备逻辑尺寸
      // 单位不一致（scaleWidth ≈ 0.38），用之缩放会把正文缩到 ~6px。
      // 详见 MarkdownStyles._baseSize 的说明。
      styleSheet: MarkdownStyles.build(isDark: Get.isDarkMode),
    );
  }

  // 页面
  Widget _buildPageInfo() {
    if (controller.isLoading.isTrue) {
      return Center(child: CupertinoActivityIndicator());
    }

    // Markdown：走真渲染，而非语法高亮。
    //
    // 必须排在下面的「代码类型」分支之前，或让那一支显式排除 md —— 因为
    // `md` **同时**命中 `PreviewHelper.isCode`（它在 `kSupportPreviewCodeTypes`
    // 里）。这里两处都做了（顺序 + 排除），避免以后有人调换顺序时静默回归。
    if (PreviewHelper.isMarkdown(controller.name)) return _buildMarkdownView();

    // 代码类型
    if (PreviewHelper.isCode(controller.name) &&
        !PreviewHelper.isMarkdown(controller.name) &&
        !PreviewHelper.isHtml(controller.name) &&
        controller.codeController != null) {
      return SingleChildScrollView(
        child: CodeTheme(
          data: CodeThemeData(
            styles: Get.isDarkMode ? atomOneDarkTheme : atomOneLightTheme,
          ),
          child: CodeField(
            controller: controller.codeController!,
            enabled: false,
            minLines: 40,
            lineNumberStyle: LineNumberStyle(margin: 0.r),
            lineNumbers: false,
          ),
        ),
      );
    }

    // PDF
    if (controller.fileType == 'pdf') return _buildPdfView();

    return Stack(
      children: [
        _buildInAppWebView(),
        controller.progress.value < 1.0
            ? LinearProgressIndicator(
                value: controller.progress.value,
                backgroundColor: Colors.transparent,
                minHeight: 2,
              )
            : SizedBox(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: _buildNavigationBar(),
      child: Obx(() => _buildPageInfo()),
    );
  }
}
