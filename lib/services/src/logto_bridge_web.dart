// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

class LogtoBridge {
  /// 跳转到 Logto 授权页
  static Future<void> redirect(String url) async {
    html.window.location.href = url;
  }

  /// 从当前 URL 提取 OAuth 回调参数
  static Map<String, String> extractCallbackParams() {
    final uri = Uri.parse(html.window.location.href);
    return {
      if (uri.queryParameters['code'] != null)
        'code': uri.queryParameters['code']!,
      if (uri.queryParameters['state'] != null)
        'state': uri.queryParameters['state']!,
    };
  }

  /// 清除 URL 中的 OAuth 参数
  static void clearCallbackParams() {
    final url =
        '${html.window.location.origin}${html.window.location.pathname}';
    html.window.history.replaceState(null, '', url);
  }

  /// 回调 URI (当前页面地址)
  static String get callbackUri => html.window.location.origin;

  /// 当前 origin
  static String get origin => html.window.location.origin;

  /// Web 不支持深度链接流，返回空流
  static Stream<Uri> get onCallback => const Stream.empty();

  /// Web 没有初始深度链接
  static Future<Uri?> getInitialLink() async => null;
}
