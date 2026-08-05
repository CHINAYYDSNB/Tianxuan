import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';
import '../models/database.dart';

/// 1Panel 数据库 API（导入实例 + 操作面板登记实例）
class DatabaseApi {
  /// GET /databases/db/list/{types} — 获取面板登记的全部数据库实例
  static Future<List<DatabaseInstance>> listInstances() async {
    final res = await ApiClient.instance.get(
      '/databases/db/list/${DbTypeMeta.apiListTypes}',
    );
    final data = _dataOf(res);
    if (data is! List) return const [];
    final list = <DatabaseInstance>[];
    for (final e in data) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final type = DbTypeMeta.fromString(m['type']?.toString());
      final sourceName =
          m['database']?.toString() ?? m['name']?.toString() ?? '';
      if (type == null || sourceName.isEmpty) continue;
      list.add(
        DatabaseInstance(
          id: m['id']?.toString() ?? sourceName,
          type: type,
          name: sourceName,
          address: m['address']?.toString() ?? 'localhost',
          port: (m['port'] as num?)?.toInt() ?? type.defaultPort,
          username: type == DbType.redis
              ? 'default'
              : (m['username']?.toString() ?? type.defaultUser),
          password: m['password']?.toString(),
          version: m['version']?.toString() ?? '',
          source: 'api',
        ),
      );
    }
    return list;
  }

  /// POST /databases/search — 面板实例下的数据库列表
  static Future<List<DatabaseItem>> searchDatabases(
    DatabaseInstance inst, {
    int page = 1,
    int pageSize = 100,
    String info = '',
  }) async {
    final path = inst.type == DbType.postgresql
        ? '/databases/pg/search'
        : '/databases/search';
    final res = await ApiClient.instance.post(
      path,
      data: {
        'page': page,
        'pageSize': pageSize,
        'info': info,
        'database': inst.name,
        'orderBy': 'createdAt',
        'order': 'null',
      },
    );
    final data = _dataOf(res);
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => DatabaseItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  /// POST /databases/status — 实例运行状态
  static Future<Map<String, String>> getStatus(DatabaseInstance inst) async {
    final res = await ApiClient.instance.post(
      '/databases/status',
      data: {'type': inst.type.apiType, 'name': inst.name},
    );
    final data = _dataOf(res);
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return const {};
  }

  /// POST /databases — 创建数据库（面板实例）
  static Future<void> createDatabase(DatabaseInstance inst, String name) async {
    final res = await ApiClient.instance.post(
      '/databases',
      data: {'type': inst.type.apiType, 'name': name, 'from': 'local'},
    );
    _checkCode(res);
  }

  /// POST /databases/del — 删除数据库
  static Future<void> deleteDatabase(
    DatabaseInstance inst,
    String name, {
    int id = 0,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/del',
      data: {
        'id': id,
        'type': inst.type.apiType,
        'database': inst.name,
        'name': name,
        'forceDelete': true,
        'deleteBackup': false,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/change/password — 修改数据库密码（value 为 Base64）
  static Future<void> changePassword(
    DatabaseInstance inst, {
    required String newPassword,
    int id = 0,
  }) async {
    final value = base64Encode(utf8.encode(newPassword));
    final res = await ApiClient.instance.post(
      '/databases/change/password',
      data: {
        'id': id,
        'from': 'local',
        'type': inst.type.apiType,
        'database': inst.name,
        'value': value,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/db/check — 测试远程连接
  static Future<bool> checkRemoteConnection(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post(
      '/databases/db/check',
      data: body,
    );
    return _dataOf(res) == true;
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

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
    }
  }
}
