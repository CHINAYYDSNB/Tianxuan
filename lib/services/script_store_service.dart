import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tianxuan/models/script_store.dart';

/// 脚本商店数据源异常。
class ScriptStoreException implements Exception {
  final String message;
  const ScriptStoreException(this.message);
  @override
  String toString() => 'ScriptStoreException: $message';
}

/// 脚本商店服务：从静态 Git 仓库（cnb.cool）拉取索引与详情。
///
/// 直接走 http，不依赖 1Panel API。若响应体以 '<' 开头（HTML 页面，例如
/// 仓库不可达或返回了网页而非 JSON），统一抛出 [ScriptStoreException]。
class ScriptStoreService {
  static const String _baseUrl =
      'https://cnb.cool/Lingqi_Team/scripts_store/scripts';

  final http.Client _client;

  ScriptStoreService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ScriptSummary>> getIndex() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/index.json'));
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('Not JSON');
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const ScriptStoreException('Index format invalid');
    }
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>) ScriptSummary.fromJson(e),
    ];
  }

  Future<ScriptDetail> getDetail(String id) async {
    final resp = await _client.get(Uri.parse('$_baseUrl/details/$id.json'));
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('Not JSON');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ScriptStoreException('Detail format invalid');
    }
    return ScriptDetail.fromJson(decoded);
  }

  /// 拉取纯文本（脚本源码或下载内容）。同样防御 HTML 响应。
  Future<String> fetchText(String url) async {
    final resp = await _client.get(Uri.parse(url));
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('Not JSON');
    }
    return body;
  }
}
