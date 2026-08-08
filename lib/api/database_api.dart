import 'dart:convert';
import 'package:dio/dio.dart';
import 'client.dart';
import '../models/database.dart';

/// 1Panel 数据库 API（端点对齐 Mono-Dash）。
class DatabaseApi {
  /// GET /databases/db/list/{types} — 获取面板登记的数据库实例。
  static Future<List<DatabaseInstance>> listInstances([
    String types = DbTypeMeta.apiListTypes,
  ]) async {
    final res = await ApiClient.instance.get('/databases/db/list/$types');
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
          id: 'api_${m['id'] ?? sourceName}',
          apiId: (m['id'] as num?)?.toInt() ?? 0,
          type: type,
          name: sourceName,
          address: m['address']?.toString() ?? 'localhost',
          port: (m['port'] as num?)?.toInt() ?? type.defaultPort,
          username: type.isRedis
              ? 'default'
              : (m['username']?.toString() ?? type.defaultUser),
          password: m['password']?.toString(),
          version: m['version']?.toString() ?? '',
          source: 'api',
          from: m['from']?.toString() ?? 'local',
        ),
      );
    }
    return list;
  }

  /// POST /databases/search — 搜索实例下的数据库列表。
  static Future<List<DatabaseItem>> searchDatabases({
    required String database,
    required String type,
    int page = 1,
    int pageSize = 100,
    String info = '',
    String orderBy = 'createdAt',
    String? order,
  }) async {
    final path = type.contains('postgresql')
        ? '/databases/pg/search'
        : '/databases/search';
    final res = await ApiClient.instance.post(
      path,
      data: {
        'page': page,
        'pageSize': pageSize,
        'info': info,
        'database': database,
        'orderBy': orderBy,
        'order': order ?? 'null',
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

  /// POST /databases/pg/{database}/load — 从 PG 服务器同步数据库列表到面板。
  static Future<void> loadPgFromRemote({required String database}) async {
    final res = await ApiClient.instance.post('/databases/pg/$database/load');
    _checkCode(res);
  }

  /// POST /databases/status — 实例运行状态。
  static Future<Map<String, String>> getStatus({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/status',
      data: {'type': type, 'name': name},
    );
    final data = _dataOf(res);
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return const {};
  }

  /// POST /databases/del/check — 删除前检查是否有网站/应用占用。
  static Future<List<DBResourceDto>> checkDelete({
    required int id,
    required String type,
    required String database,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/del/check',
      data: {'id': id, 'type': type, 'database': database},
    );
    final data = _dataOf(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => DBResourceDto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /databases/del — 删除数据库。
  static Future<void> deleteDatabase({
    required int id,
    required String type,
    required String database,
    bool forceDelete = false,
    bool deleteBackup = false,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/del',
      data: {
        'id': id,
        'type': type,
        'database': database,
        'forceDelete': forceDelete,
        'deleteBackup': deleteBackup,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/change/password — 修改数据库密码（value 为 Base64）。
  static Future<void> changePassword({
    required int id,
    required String from,
    required String type,
    required String database,
    required String value,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/change/password',
      data: {
        'id': id,
        'from': from,
        'type': type,
        'database': database,
        'value': value,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/change/access — 修改访问权限（value 为 host 规则）。
  static Future<void> changeAccess({
    required int id,
    required String from,
    required String type,
    required String database,
    required String value,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/change/access',
      data: {
        'id': id,
        'from': from,
        'type': type,
        'database': database,
        'value': value,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/db/check — 测试远程数据库连接。
  static Future<bool> checkRemoteConnection(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post(
      '/databases/db/check',
      data: body,
    );
    return _dataOf(res) == true;
  }

  /// POST /databases/db — 创建远程数据库连接。
  static Future<void> createRemoteDatabase(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post('/databases/db', data: body);
    _checkCode(res);
  }

  /// POST /databases/db/search — 搜索远程数据库连接列表。
  static Future<List<DatabaseInstance>> searchRemoteDatabases({
    required String type,
    int page = 1,
    int pageSize = 100,
    String info = '',
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/db/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'info': info,
        'type': type,
        'orderBy': 'createdAt',
        'order': 'null',
      },
    );
    final data = _dataOf(res);
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => _remoteInstance(Map<String, dynamic>.from(e), type))
          .where((e) => e != null)
          .cast<DatabaseInstance>()
          .toList();
    }
    return const [];
  }

  /// GET /databases/db/{name} — 获取远程连接详情。
  static Future<Map<String, dynamic>> getDatabase(String name) async {
    final res = await ApiClient.instance.get('/databases/db/$name');
    final data = _dataOf(res);
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// POST /databases/db/update — 更新远程数据库连接。
  static Future<void> updateRemoteDatabase(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post(
      '/databases/db/update',
      data: body,
    );
    _checkCode(res);
  }

  /// POST /databases/db/del — 解绑远程数据库实例。
  static Future<void> deleteRemoteDatabase({
    required int id,
    required String database,
    bool forceDelete = false,
    bool deleteBackup = false,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/db/del',
      data: {
        'id': id,
        'database': database,
        'forceDelete': forceDelete,
        'deleteBackup': deleteBackup,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/remote — 查询本机实例是否允许远程 root 访问。
  static Future<bool> getRemoteAccess({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/remote',
      data: {'type': type, 'name': name},
    );
    return _dataOf(res) == true;
  }

  /// 设置本机实例是否允许远程 root 访问。
  static Future<void> updateRemoteAccess({
    required String type,
    required String database,
    required bool remote,
  }) {
    return changeAccess(
      id: 0,
      from: 'local',
      type: type,
      database: database,
      value: remote ? '%' : 'localhost',
    );
  }

  /// POST /databases/format/options — 获取字符集与排序规则选项。
  static Future<List<FormatCollationOption>> getFormatOptions(
    String name,
  ) async {
    final res = await ApiClient.instance.post(
      '/databases/format/options',
      data: {'name': name},
    );
    final data = _dataOf(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (e) => FormatCollationOption.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  /// POST /databases — 创建数据库。
  static Future<void> createDatabase(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post('/databases', data: body);
    _checkCode(res);
  }

  /// POST /databases/pg — 创建 PostgreSQL 数据库。
  static Future<void> createPgDatabase(Map<String, dynamic> body) async {
    final res = await ApiClient.instance.post('/databases/pg', data: body);
    _checkCode(res);
  }

  /// POST /databases/load — 从服务器同步数据库（面板与实例对齐）。
  static Future<void> loadFromRemote({
    required String from,
    required String type,
    required String database,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/load',
      data: {'from': from, 'type': type, 'database': database},
    );
    _checkCode(res);
  }

  /// POST /databases/common/load/file — 加载数据库配置文件内容。
  static Future<String> loadConfigFile({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/common/load/file',
      data: {'type': type, 'name': name},
    );
    return _dataOf(res)?.toString() ?? '';
  }

  /// POST /databases/common/update/conf — 更新数据库配置文件。
  static Future<void> updateConfigFile({
    required String type,
    required String database,
    required String file,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/common/update/conf',
      data: {'type': type, 'database': database, 'file': file},
    );
    _checkCode(res);
  }

  /// POST /databases/variables — 加载 MySQL 性能变量。
  static Future<MysqlVariables> loadVariables({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/variables',
      data: {'type': type, 'name': name},
    );
    final data = _dataOf(res);
    return MysqlVariables.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  /// POST /databases/variables/update — 更新 MySQL 性能变量。
  static Future<void> updateVariables({
    required String type,
    required String database,
    required List<Map<String, dynamic>> variables,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/variables/update',
      data: {'type': type, 'database': database, 'variables': variables},
    );
    _checkCode(res);
  }

  /// POST /databases/redis/status — Redis 运行状态。
  static Future<Map<String, String>> getRedisStatus({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/status',
      data: {'type': type, 'name': name},
    );
    final data = _dataOf(res);
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return const {};
  }

  /// POST /databases/redis/conf — Redis 配置。
  static Future<RedisConfDto> getRedisConf({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/conf',
      data: {'type': type, 'name': name},
    );
    final data = _dataOf(res);
    return RedisConfDto.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  /// POST /databases/redis/conf/update — 更新 Redis 配置。
  static Future<void> updateRedisConf({
    required String dbType,
    required String database,
    required String timeout,
    required String maxclients,
    required String maxmemory,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/conf/update',
      data: {
        'dbType': dbType,
        'database': database,
        'timeout': timeout,
        'maxclients': maxclients,
        'maxmemory': maxmemory,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/redis/password — 修改 Redis 密码。
  static Future<void> changeRedisPassword({
    required String database,
    required String value,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/password',
      data: {'database': database, 'value': value},
    );
    _checkCode(res);
  }

  /// POST /databases/redis/persistence/conf — Redis 持久化配置。
  static Future<RedisPersistenceDto> getRedisPersistence({
    required String type,
    required String name,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/persistence/conf',
      data: {'type': type, 'name': name},
    );
    final data = _dataOf(res);
    return RedisPersistenceDto.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  /// POST /databases/redis/persistence/update — 更新 Redis AOF 持久化。
  static Future<void> updateRedisAofPersistence({
    required String dbType,
    required String database,
    required String appendonly,
    required String appendfsync,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/persistence/update',
      data: {
        'dbType': dbType,
        'database': database,
        'type': 'aof',
        'appendonly': appendonly,
        'appendfsync': appendfsync,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/redis/persistence/update — 更新 Redis RDB 持久化。
  static Future<void> updateRedisRdbPersistence({
    required String dbType,
    required String database,
    required String save,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/redis/persistence/update',
      data: {
        'dbType': dbType,
        'database': database,
        'type': 'rbd',
        'save': save,
      },
    );
    _checkCode(res);
  }

  /// GET /databases/db/item/{dbType} — 获取数据库项列表（供计划任务选择）。
  static Future<List<DatabaseItem>> loadDatabaseItems(String dbType) async {
    final res = await ApiClient.instance.get('/databases/db/item/$dbType');
    final data = _dataOf(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => DatabaseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static DatabaseInstance? _remoteInstance(
    Map<String, dynamic> m,
    String type,
  ) {
    final dbType = DbTypeMeta.fromString(type);
    if (dbType == null) return null;
    final name = m['name']?.toString() ?? m['database']?.toString() ?? '';
    if (name.isEmpty) return null;
    return DatabaseInstance(
      id: 'remote_${m['id'] ?? name}',
      apiId: (m['id'] as num?)?.toInt() ?? 0,
      type: dbType,
      name: name,
      address: m['address']?.toString() ?? '',
      port: (m['port'] as num?)?.toInt() ?? dbType.defaultPort,
      username: m['username']?.toString() ?? dbType.defaultUser,
      password: m['password']?.toString(),
      version: m['version']?.toString() ?? '',
      source: 'api',
      from: 'remote',
    );
  }

  static dynamic _dataOf(Response res) {
    final data = res.data;
    if (data is Map) {
      if (data.containsKey('code') && data['code'] != 200) {
        throw Exception(
          data['message']?.toString() ?? '接口返回异常(code=${data['code']})',
        );
      }
      return data['data'];
    }
    return null;
  }

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(
        data['message']?.toString() ?? '接口返回异常(code=${data['code']})',
      );
    }
  }

  /// POST /databases/bind — 绑定 MySQL 用户（绑定即创建/授权）。
  static Future<void> bindUser({
    required String database,
    required String db,
    required String username,
    required String password,
    required String permission,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/bind',
      data: {
        'database': database,
        'db': db,
        'username': username,
        'password': encodeValue(password),
        'permission': permission,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/pg/bind — 绑定 PostgreSQL 用户。
  static Future<void> bindPgUser({
    required String name,
    required String database,
    required String username,
    required String password,
    bool superUser = false,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/pg/bind',
      data: {
        'name': name,
        'database': database,
        'username': username,
        'password': encodeValue(password),
        'superUser': superUser,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/pg/privileges — 修改 PG 用户超级权限。
  static Future<void> changePgPrivileges({
    required String name,
    required String database,
    required String username,
    required bool superUser,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/pg/privileges',
      data: {
        'name': name,
        'database': database,
        'username': username,
        'superUser': superUser,
      },
    );
    _checkCode(res);
  }

  /// POST /databases/pg/password — 修改 PG 用户密码。
  static Future<void> changePgPassword({
    required String name,
    required String database,
    required String username,
    required String value,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/pg/password',
      data: {
        'name': name,
        'database': database,
        'username': username,
        'value': encodeValue(value),
      },
    );
    _checkCode(res);
  }

  /// POST /databases/description/update — 更新数据库描述。
  static Future<void> updateDescription({
    required int id,
    required String description,
  }) async {
    final res = await ApiClient.instance.post(
      '/databases/description/update',
      data: {'id': id, 'description': description},
    );
    _checkCode(res);
  }

  /// POST /databases/options — 列出面板登记的可绑数据库名。
  static Future<List<String>> listDatabaseOptions() async {
    final res = await ApiClient.instance.get('/databases/options');
    final data = _dataOf(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => e['name']?.toString() ?? e['database']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Base64 编码（修改密码/访问权限共用）。
  static String encodeValue(String value) => base64Encode(utf8.encode(value));
}
