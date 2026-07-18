import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/script_store_item.dart';
import 'client.dart';

/// 脚本商店 API — 多源测速，自动选最快
class ScriptStoreApi {
  static const _proxyBase = 'http://localhost:25568';

  static const _sources = [
    _Source(
      name: 'CNB',
      rawBase: 'https://cnb.cool/Lingqi_Team/Tianxuan/-/raw/main/scripts',
    ),
    _Source(
      name: 'GitHub',
      rawBase: 'https://raw.githubusercontent.com/CHINAYYDSNB/Tianxuan/main/scripts',
    ),
  ];

  /// 缓存最快源（每次 fetchIndex 时刷新）
  static _Source? _fastest;

  /// 竞速：同时请求所有源，返回第一个成功的响应
  static Future<String> _race(
    String Function(_Source src) buildUrl, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<({_Source src, String body})>();
    var failCount = 0;

    for (final src in _sources) {
      final url = buildUrl(src);
      // ignore: unawaited_futures
      http.get(Uri.parse(url)).timeout(timeout).then((r) {
        if (r.statusCode == 200 && !completer.isCompleted) {
          completer.complete((src: src, body: r.body));
        }
      }).catchError((_) {
        failCount++;
        if (failCount >= _sources.length && !completer.isCompleted) {
          completer.completeError(
            Exception('所有脚本源均不可用，请检查网络连接'),
          );
        }
      });
    }

    final result = await completer.future;
    _fastest = result.src;
    return result.body;
  }

  /// 取索引 — 竞速所有源，缓存最快
  static Future<ScriptIndex> fetchIndex() async {
    // 先试本地代理
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/index'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return ScriptIndex.fromJson(jsonDecode(r.body));
    } catch (_) {}

    // 竞速直连源
    try {
      final body = await _race(
        (src) => '${src.rawBase}/index.json',
      );
      return ScriptIndex.fromJson(jsonDecode(body));
    } catch (e) {
      // 竞速失败，尝试已有最快源
      if (_fastest != null) {
        final r = await http
            .get(Uri.parse('${_fastest!.rawBase}/index.json'))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) return ScriptIndex.fromJson(jsonDecode(r.body));
      }
      rethrow;
    }
  }

  /// 取脚本详情
  static Future<ScriptDetail> fetchDetail(String id) async {
    // 先试本地代理
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script/detail/$id'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return ScriptDetail.fromJson(jsonDecode(r.body));
    } catch (_) {}

    // 用最快源（如果有），否则竞速
    final base = _fastest;
    if (base != null) {
      try {
        final r = await http
            .get(Uri.parse('${base.rawBase}/details/$id.json'))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) return ScriptDetail.fromJson(jsonDecode(r.body));
      } catch (_) {}
    }

    // 回退竞速
    final body = await _race(
      (src) => '${src.rawBase}/details/$id.json',
      timeout: const Duration(seconds: 10),
    );
    return ScriptDetail.fromJson(jsonDecode(body));
  }

  /// 下载脚本内容
  static Future<String> downloadScript(String url) async {
    // 先试本地代理
    try {
      final r = await http
          .get(Uri.parse('$_proxyBase/api/script-download?url=${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.body;
    } catch (_) {}

    // 直连
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('下载失败 (${r.statusCode})');
    return r.body;
  }

  /// 上传脚本到 1Panel
  static Future<void> uploadToServer(String path, String content) async {
    await ApiClient.instance.post('/files/save', data: {'path': path, 'content': content});
  }

  /// 通过 server.mjs 执行脚本
  static Future<String> executeViaProxy(String scriptPath) async {
    final url = ApiClient.instance.serverUrl.replaceAll(RegExp(r':\d+$'), ':25568');
    final r = await http.post(
      Uri.parse('$url/api/script/exec'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'path': scriptPath}),
    );
    if (r.statusCode != 200) throw Exception('执行失败 (${r.statusCode})');
    return r.body;
  }
}

class _Source {
  final String name;
  final String rawBase;
  const _Source({required this.name, required this.rawBase});
}
