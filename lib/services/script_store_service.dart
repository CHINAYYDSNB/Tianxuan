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

/// 脚本商店服务：从 Tianxuan 仓库的静态目录（GitHub raw）拉取索引与详情。
///
/// 数据源位于 `CHINAYYDSNB/Tianxuan` 仓库的 `scripts/` 目录，通过
/// raw.githubusercontent.com 以纯文本形式提供，无需鉴权。
/// 若响应非正常 JSON（网页、404 文本等），统一抛出 [ScriptStoreException]。
class ScriptStoreService {
  static const String _baseUrl =
      'https://gitee.com/happyfurry/scripts_store/raw/main/scripts';

  final http.Client _client;

  ScriptStoreService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ScriptSummary>> getIndex() async {
    final resp = await _client.get(Uri.parse('$_baseUrl/index.json'));
    if (resp.statusCode != 200) {
      throw ScriptStoreException('索引拉取失败 (HTTP ${resp.statusCode})');
    }
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('索引不是 JSON（返回了网页）');
    }
    final decoded = jsonDecode(body);
    late List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['scripts'] is List) {
      // 兼容 { "version": 1, "updatedAt": "...", "scripts": [ ... ] } 形式。
      list = decoded['scripts'] as List<dynamic>;
    } else {
      throw const ScriptStoreException('Index format invalid');
    }
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) ScriptSummary.fromJson(e),
    ];
  }

  Future<ScriptDetail> getDetail(String id) async {
    final resp = await _client.get(Uri.parse('$_baseUrl/details/$id.json'));
    if (resp.statusCode != 200) {
      throw ScriptStoreException('详情拉取失败 (HTTP ${resp.statusCode})');
    }
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('详情不是 JSON（返回了网页）');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const ScriptStoreException('Detail format invalid');
    }
    return ScriptDetail.fromJson(decoded);
  }

  /// 拉取纯文本（脚本源码或下载内容）。同样防御 HTML 与非 200 响应。
  ///
  /// 注意：raw.githubusercontent 在文件不存在时返回纯文本 `404: Not Found`，
  /// 因此必须以状态码拦截，避免把错误文本当脚本内容返回给安装流程。
  Future<String> fetchText(String url) async {
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw ScriptStoreException('下载失败 (HTTP ${resp.statusCode})');
    }
    final body = resp.body;
    if (body.startsWith('<')) {
      throw const ScriptStoreException('不是文本（返回了网页）');
    }
    return body;
  }
}
