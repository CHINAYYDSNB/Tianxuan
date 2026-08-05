import 'package:dio/dio.dart';
import 'client.dart';

/// 计划任务（1Panel cronjobs API）
class CronjobItem {
  final String name;
  final String type;
  final String spec;
  final bool status;
  final int lastRecordId;

  const CronjobItem({
    this.name = '',
    this.type = '',
    this.spec = '',
    this.status = false,
    this.lastRecordId = 0,
  });

  bool get isRunning => status;

  factory CronjobItem.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k]?.toString() ?? '';
    return CronjobItem(
      name: s('name'),
      type: s('type'),
      spec: s('spec'),
      status: json['status'] == true || s('status') == '1',
      lastRecordId: (json['lastRecordId'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 计划任务 API（优先调用，失败由调用方 fallback SSH）
class CronjobApi {
  /// POST /cronjobs/search — 列表
  static Future<List<CronjobItem>> list({
    int page = 1,
    int pageSize = 100,
  }) async {
    final res = await ApiClient.instance.post(
      '/cronjobs/search',
      data: {'page': page, 'pageSize': pageSize},
    );
    return _items(res).map((e) => CronjobItem.fromJson(_asMap(e))).toList();
  }

  /// POST /cronjobs — 创建 shell 脚本任务
  static Future<void> createShell({
    required String name,
    required String spec,
    required String script,
  }) async {
    final res = await ApiClient.instance.post(
      '/cronjobs',
      data: {
        'name': name,
        'type': 'shell',
        'spec': spec,
        'specType': 'cron',
        'script': script,
      },
    );
    _checkCode(res);
  }

  /// POST /cronjobs/del — 删除
  static Future<void> delete(String name) async {
    final res = await ApiClient.instance.post(
      '/cronjobs/del',
      data: {'name': name},
    );
    _checkCode(res);
  }

  /// POST /cronjobs/handle — 立即执行一次
  static Future<void> runOnce(String name) async {
    final res = await ApiClient.instance.post(
      '/cronjobs/handle',
      data: {'name': name},
    );
    _checkCode(res);
  }

  /// POST /cronjobs/status — 启用/停用
  static Future<void> setStatus(String name, bool status) async {
    final res = await ApiClient.instance.post(
      '/cronjobs/status',
      data: {'name': name, 'status': status},
    );
    _checkCode(res);
  }

  /// POST /cronjobs/search/records — 执行记录
  static Future<List<Map<String, dynamic>>> records(String name) async {
    final res = await ApiClient.instance.post(
      '/cronjobs/search/records',
      data: {'cronjobName': name},
    );
    final data = _dataOf(res);
    if (data is Map && data['records'] is List) {
      return (data['records'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  static dynamic _dataOf(Response res) {
    final data = res.data;
    if (data is Map) {
      if (data.containsKey('code') && data['code'] != 200) {
        throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
      }
      return data['data'];
    }
    return null;
  }

  static List<dynamic> _items(Response res) {
    final data = _dataOf(res);
    if (data is Map && data['items'] is List) {
      return data['items'] as List;
    }
    return const [];
  }

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }
}
