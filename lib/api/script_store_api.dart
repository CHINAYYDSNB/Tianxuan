import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/script_store_item.dart';
import 'client.dart';

/// 脚本商店 API — 多源测速，自动选最快
class ScriptStoreApi {
  static const _proxyBase = 'http://localhost:25568';

  /// 脚本源：CNB 仓库当前未初始化（返回 HTML 错误页），仅使用 GitHub 源。
  static const _sources = [
    ScriptSource(
      name: 'GitHub',
      rawBase:
          'https://raw.githubusercontent.com/CHINAYYDSNB/Tianxuan/main/scripts',
    ),
  ];

  /// 竞速：同时请求所有源，返回第一个成功的响应。
  /// 任何非 200 或非 JSON 响应均视为失败，避免 HTML 错误页触发 FormatException。
  /// [sources] 可注入以便测试；默认使用 [_sources]。
  static Future<String> _race(
    String Function(ScriptSource src) buildUrl, {
    Duration timeout = const Duration(seconds: 8),
    List<ScriptSource>? sources,
    http.Client? client,
  }) async {
    final srcList = sources ?? _sources;
    final httpClient = client ?? http.Client();
    if (srcList.isEmpty) {
      throw Exception('脚本商店未配置任何可用源');
    }
    final completer = Completer<({ScriptSource src, String body})>();
    var failCount = 0;

    void _maybeFail() {
      if (failCount >= srcList.length && !completer.isCompleted) {
        completer.completeError(Exception('脚本源不可用，请检查网络连接'));
      }
    }

    for (final src in srcList) {
      final url = buildUrl(src);
      // ignore: unawaited_futures
      httpClient
          .get(Uri.parse(url))
          .timeout(timeout)
          .then((r) {
            if (completer.isCompleted) return;
            if (r.statusCode != 200) {
              failCount++;
              _maybeFail();
              return;
            }
            // 防御：HTML 错误页即使 200 也会以 <!DOCTYPE 开头
            final body = r.body;
            if (isHtmlBody(body)) {
              failCount++;
              _maybeFail();
              return;
            }
            completer.complete((src: src, body: body));
          })
          .catchError((_) {
            failCount++;
            _maybeFail();
          });
    }

    final result = await completer.future;
    return result.body;
  }

  /// 取索引 — 竞速所有源
  static Future<ScriptIndex> fetchIndex({
    List<ScriptSource>? sources,
    http.Client? client,
  }) async {
    // 先试本地代理
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/index'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final body = r.body;
        if (!_looksLikeHtml(body)) {
          return ScriptIndex.fromJson(jsonDecode(body));
        }
      }
    } catch (_) {}

    // 竞速直连源
    final body = await _race(
      (src) => '${src.rawBase}/index.json',
      sources: sources,
      client: client,
    );
    if (_looksLikeHtml(body)) {
      throw Exception('脚本源返回了非预期内容');
    }
    return ScriptIndex.fromJson(jsonDecode(body));
  }

  /// 判断响应体是否为 HTML 错误页（避免 jsonDecode 崩溃）。
  static bool isHtmlBody(String body) {
    final t = body.trimLeft();
    return t.startsWith('<!DOCTYPE') ||
        t.startsWith('<html') ||
        t.startsWith('<');
  }

  static bool _looksLikeHtml(String body) => isHtmlBody(body);

  /// 取脚本详情
  static Future<ScriptDetail> fetchDetail(
    String id, {
    List<ScriptSource>? sources,
    http.Client? client,
  }) async {
    // 先试本地代理
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/detail/$id'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200 && !_looksLikeHtml(r.body)) {
        return ScriptDetail.fromJson(jsonDecode(r.body));
      }
    } catch (_) {}

    // 竞速直连源
    final body = await _race(
      (src) => '${src.rawBase}/details/$id.json',
      timeout: const Duration(seconds: 10),
      sources: sources,
      client: client,
    );
    if (_looksLikeHtml(body)) {
      throw Exception('脚本源返回了非预期内容');
    }
    return ScriptDetail.fromJson(jsonDecode(body));
  }

  /// 下载脚本内容
  static Future<String> downloadScript(String url) async {
    // 先试本地代理
    try {
      final r = await http
          .get(
            Uri.parse(
              '$_proxyBase/api/script-download?url=${Uri.encodeComponent(url)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.body;
    } catch (_) {}

    // 直连
    final r = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('下载失败 (${r.statusCode})');
    return r.body;
  }

  /// 上传脚本到 1Panel
  static Future<void> uploadToServer(String path, String content) async {
    await ApiClient.instance.post(
      '/files/save',
      data: {'path': path, 'content': content},
    );
  }

  /// 通过 server.mjs 执行脚本
  static Future<String> executeViaProxy(String scriptPath) async {
    final url = ApiClient.instance.serverUrl.replaceAll(
      RegExp(r':\d+$'),
      ':25568',
    );
    final r = await http.post(
      Uri.parse('$url/api/script/exec'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': scriptPath}),
    );
    if (r.statusCode != 200) throw Exception('执行失败 (${r.statusCode})');
    return r.body;
  }
}

class ScriptSource {
  final String name;
  final String rawBase;
  const ScriptSource({required this.name, required this.rawBase});
}
