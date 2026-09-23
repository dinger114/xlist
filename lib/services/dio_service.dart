import 'dart:io';

import 'package:dio/io.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' show Get, GetxService;
import 'package:get/get_instance/src/extension_instance.dart';

import 'package:xlist/helper/index.dart';
import 'package:xlist/storages/index.dart';

// Dio
class DioService extends GetxService {
  static DioService get to => Get.find();

  // Dio
  final Dio _dio = Dio();
  Dio get dio => _dio;
  Map<String, String> defaultHeaders = {}; // 默认请求头

  // 连接超时时间
  static const Duration connectTimeout = Duration(seconds: 10 * 1000);

  // 响应超时时间 5 min
  static const Duration receiveTimeout = Duration(seconds: 300 * 1000);

  // Init
  Future<DioService> init() async {
    // 设置一些默认信息
    _dio.options
      ..connectTimeout = connectTimeout
      ..receiveTimeout = receiveTimeout;

    // Certificate
    // 用 createHttpClient 而非已弃用的 onHttpClientCreate：后者在 dio 6 会被移除。
    // 签名也换了 —— createHttpClient 是 `HttpClient Function()`，不接收参数。
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final SecurityContext sc = SecurityContext();
      sc.allowLegacyUnsafeRenegotiation = true;

      // HttpClient
      HttpClient httpClient = HttpClient(context: sc);
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

      return httpClient;
    };

    // Interceptor
    _dio.interceptors.add(DioInterceptors());
    defaultHeaders = DriverHelper.getHeaders(null, null);
    return this;
  }
}

class DioInterceptors extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = Get.find<UserStorage>().token.val;
    options.headers.addAll(
      Map.from(DioService.to.defaultHeaders)
        ..addAll({HttpHeaders.authorizationHeader: token}),
    );
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 错误处理
    if (response.data == null) {
      response.data = {'message': '您的网络不太好, 请刷新页面重试吧', 'code': -1};
    }

    // Next
    handler.next(response);
  }
}
