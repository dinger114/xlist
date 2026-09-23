import 'package:xlist/constants/index.dart';

class DriverHelper {
  /// 默认请求头
  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  /// 获取请求头
  /// [provider] 云盘提供商
  /// [url] 下载地址
  static Map<String, String> getHeaders(String? provider, String? url) {
    Map<String, String> headers = {};
    if (provider == null) return defaultHeaders;

    // 获取域名
    String host = '';
    if (url != null) host = Uri.parse(url).host;

    // 阿里云盘
    if (provider.startsWith(Provider.aliyunDrive) ||
        host.contains('aliyundrive.net')) {
      headers = {'Referer': 'https://www.aliyundrive.com/'};
    }

    // 百度网盘
    if (provider.startsWith(Provider.baidu) || host.contains('baidupcs.com')) {
      headers = {'User-Agent': 'pan.baidu.com'};
    }

    return Map.from(defaultHeaders)..addAll(headers);
  }
}
