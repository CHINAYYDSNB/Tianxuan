import '../api/client.dart';
import '../api/database_api.dart';
import '../models/database.dart';
import 'ssh_database_service.dart';

/// 数据库操作服务抽象。
/// 实例信息（凭据）来自本地保存；操作优先 API，失败 fallback SSH。
abstract class DatabaseService {
  Future<List<DatabaseInstance>> listInstances();

  Future<DatabaseCheckDto> checkInstalled(DatabaseInstance inst);

  Future<List<DatabaseItem>> searchDatabases(
    DatabaseInstance inst, {
    int page = 1,
    int pageSize = 100,
    String info = '',
  });

  Future<List<FormatCollationOption>> getFormatOptions(DatabaseInstance inst);

  Future<void> createDatabase(
    DatabaseInstance inst,
    String name, {
    String format = '',
    String collation = '',
  });

  /// 删除前检查占用；无占用或强制删除时删除。
  Future<void> deleteDatabase(
    DatabaseInstance inst,
    DatabaseItem item, {
    bool forceDelete = false,
  });

  Future<void> changePassword(DatabaseInstance inst, String newPassword);

  Future<void> changeAccess(DatabaseInstance inst, String value);

  Future<bool> getRemoteAccess(DatabaseInstance inst);

  Future<void> updateRemoteAccess(DatabaseInstance inst, bool remote);

  Future<void> loadFromRemote(DatabaseInstance inst);

  Future<void> loadPgFromRemote(DatabaseInstance inst);

  Future<Map<String, String>> getStatus(DatabaseInstance inst);

  Future<String> loadConfigFile(DatabaseInstance inst);

  Future<void> updateConfigFile(DatabaseInstance inst, String file);

  Future<MysqlVariables> loadVariables(DatabaseInstance inst);

  Future<void> updateVariables(
    DatabaseInstance inst,
    List<Map<String, dynamic>> variables,
  );

  Future<Map<String, String>> getRedisStatus(DatabaseInstance inst);

  Future<RedisConfDto> getRedisConf(DatabaseInstance inst);

  Future<void> updateRedisConf(
    DatabaseInstance inst, {
    required String timeout,
    required String maxclients,
    required String maxmemory,
  });

  Future<void> changeRedisPassword(DatabaseInstance inst, String value);

  Future<RedisPersistenceDto> getRedisPersistence(DatabaseInstance inst);

  Future<void> updateRedisAofPersistence(
    DatabaseInstance inst, {
    required String appendonly,
    required String appendfsync,
  });

  Future<void> updateRedisRdbPersistence(
    DatabaseInstance inst, {
    required String save,
  });

  /// 返回 null 表示连接成功，否则返回错误信息。
  Future<String?> testConnection(DatabaseInstance inst);

  // ── 用户与权限管理 ──

  /// 列出实例下的数据库用户（MySQL: SELECT user,host FROM mysql.user；PG: \du）。
  Future<List<DatabaseUserInfo>> listUsers(DatabaseInstance inst);

  /// 绑定/创建用户（绑定即授权）。
  Future<void> bindUser(
    DatabaseInstance inst, {
    required String database,
    required String username,
    required String password,
    String permission = '%',
    bool isSuperUser = false,
  });

  /// 修改用户访问权限（host 白名单）。
  Future<void> changeUserAccess(
    DatabaseInstance inst,
    String username, {
    String permission = '%',
  });

  /// 修改用户密码。
  Future<void> changeUserPassword(
    DatabaseInstance inst,
    String username,
    String newPassword,
  );

  /// 删除用户（SSH DROP USER；API 无此端点）。
  Future<void> deleteUser(DatabaseInstance inst, String username);

  /// 修改 PG 用户超级权限。
  Future<void> changeUserSuperUser(
    DatabaseInstance inst,
    String username, {
    required bool isSuperUser,
    required String database,
  });
}

/// 1Panel API 实现（面板登记实例可用）。
class ApiDatabaseService implements DatabaseService {
  @override
  Future<List<DatabaseInstance>> listInstances() => DatabaseApi.listInstances();

  @override
  Future<DatabaseCheckDto> checkInstalled(DatabaseInstance inst) async {
    final res = await _post('/apps/installed/check', {
      'key': inst.type.apiType,
      'name': inst.name,
    });
    final data = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return DatabaseCheckDto.fromJson(data);
  }

  @override
  Future<List<DatabaseItem>> searchDatabases(
    DatabaseInstance inst, {
    int page = 1,
    int pageSize = 100,
    String info = '',
  }) => DatabaseApi.searchDatabases(
    database: inst.name,
    type: inst.type.apiType,
    page: page,
    pageSize: pageSize,
    info: info,
  );

  @override
  Future<List<FormatCollationOption>> getFormatOptions(DatabaseInstance inst) =>
      DatabaseApi.getFormatOptions(inst.name);

  @override
  Future<void> createDatabase(
    DatabaseInstance inst,
    String name, {
    String format = '',
    String collation = '',
  }) async {
    final body = <String, dynamic>{
      'type': inst.type.apiType,
      'name': name,
      'from': inst.isRemote ? 'remote' : 'local',
      'database': inst.name,
    };
    if (format.isNotEmpty) body['format'] = format;
    if (collation.isNotEmpty) body['collation'] = collation;
    if (inst.type.isPostgres) {
      await DatabaseApi.createPgDatabase(body);
    } else {
      await DatabaseApi.createDatabase(body);
    }
  }

  @override
  Future<void> deleteDatabase(
    DatabaseInstance inst,
    DatabaseItem item, {
    bool forceDelete = false,
  }) async {
    if (inst.isRemote) {
      await DatabaseApi.deleteRemoteDatabase(
        id: item.id,
        database: inst.name,
        forceDelete: forceDelete,
      );
      return;
    }
    final occupied = await DatabaseApi.checkDelete(
      id: item.id,
      type: inst.type.apiType,
      database: inst.name,
    );
    if (occupied.isNotEmpty && !forceDelete) {
      final names = occupied.map((e) => '${e.type}:${e.name}').join('、');
      throw Exception('数据库被占用：$names，请先在对应位置解除引用');
    }
    await DatabaseApi.deleteDatabase(
      id: item.id,
      type: inst.type.apiType,
      database: inst.name,
      forceDelete: forceDelete || occupied.isNotEmpty,
      deleteBackup: false,
    );
  }

  @override
  Future<void> changePassword(DatabaseInstance inst, String newPassword) {
    return DatabaseApi.changePassword(
      id: inst.apiId,
      from: inst.isRemote ? 'remote' : 'local',
      type: inst.type.apiType,
      database: inst.name,
      value: DatabaseApi.encodeValue(newPassword),
    );
  }

  @override
  Future<void> changeAccess(DatabaseInstance inst, String value) {
    return DatabaseApi.changeAccess(
      id: inst.apiId,
      from: inst.isRemote ? 'remote' : 'local',
      type: inst.type.apiType,
      database: inst.name,
      value: value,
    );
  }

  @override
  Future<bool> getRemoteAccess(DatabaseInstance inst) =>
      DatabaseApi.getRemoteAccess(type: inst.type.apiType, name: inst.name);

  @override
  Future<void> updateRemoteAccess(DatabaseInstance inst, bool remote) =>
      DatabaseApi.updateRemoteAccess(
        type: inst.type.apiType,
        database: inst.name,
        remote: remote,
      );

  @override
  Future<void> loadFromRemote(DatabaseInstance inst) =>
      DatabaseApi.loadFromRemote(
        from: inst.isRemote ? 'remote' : 'local',
        type: inst.type.apiType,
        database: inst.name,
      );

  @override
  Future<void> loadPgFromRemote(DatabaseInstance inst) =>
      DatabaseApi.loadPgFromRemote(database: inst.name);

  @override
  Future<Map<String, String>> getStatus(DatabaseInstance inst) =>
      DatabaseApi.getStatus(type: inst.type.apiType, name: inst.name);

  @override
  Future<String> loadConfigFile(DatabaseInstance inst) =>
      DatabaseApi.loadConfigFile(type: inst.type.apiType, name: inst.name);

  @override
  Future<void> updateConfigFile(DatabaseInstance inst, String file) =>
      DatabaseApi.updateConfigFile(
        type: inst.type.apiType,
        database: inst.name,
        file: file,
      );

  @override
  Future<MysqlVariables> loadVariables(DatabaseInstance inst) =>
      DatabaseApi.loadVariables(type: inst.type.apiType, name: inst.name);

  @override
  Future<void> updateVariables(
    DatabaseInstance inst,
    List<Map<String, dynamic>> variables,
  ) => DatabaseApi.updateVariables(
    type: inst.type.apiType,
    database: inst.name,
    variables: variables,
  );

  @override
  Future<Map<String, String>> getRedisStatus(DatabaseInstance inst) =>
      DatabaseApi.getRedisStatus(type: inst.type.apiType, name: inst.name);

  @override
  Future<RedisConfDto> getRedisConf(DatabaseInstance inst) =>
      DatabaseApi.getRedisConf(type: inst.type.apiType, name: inst.name);

  @override
  Future<void> updateRedisConf(
    DatabaseInstance inst, {
    required String timeout,
    required String maxclients,
    required String maxmemory,
  }) => DatabaseApi.updateRedisConf(
    dbType: inst.type.apiType,
    database: inst.name,
    timeout: timeout,
    maxclients: maxclients,
    maxmemory: maxmemory,
  );

  @override
  Future<void> changeRedisPassword(DatabaseInstance inst, String value) =>
      DatabaseApi.changeRedisPassword(
        database: inst.name,
        value: DatabaseApi.encodeValue(value),
      );

  @override
  Future<RedisPersistenceDto> getRedisPersistence(DatabaseInstance inst) =>
      DatabaseApi.getRedisPersistence(type: inst.type.apiType, name: inst.name);

  @override
  Future<void> updateRedisAofPersistence(
    DatabaseInstance inst, {
    required String appendonly,
    required String appendfsync,
  }) => DatabaseApi.updateRedisAofPersistence(
    dbType: inst.type.apiType,
    database: inst.name,
    appendonly: appendonly,
    appendfsync: appendfsync,
  );

  @override
  Future<void> updateRedisRdbPersistence(
    DatabaseInstance inst, {
    required String save,
  }) => DatabaseApi.updateRedisRdbPersistence(
    dbType: inst.type.apiType,
    database: inst.name,
    save: save,
  );

  @override
  Future<String?> testConnection(DatabaseInstance inst) async {
    try {
      final ok = await DatabaseApi.checkRemoteConnection({
        'type': inst.type.apiType,
        'name': inst.name,
        'address': inst.address,
        'port': inst.port,
        'username': inst.username,
        'password': inst.password ?? '',
      });
      return ok ? null : '连接失败';
    } catch (e) {
      return '$e';
    }
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post(path, data: data);
    final body = res.data;
    if (body is Map && body.containsKey('code') && body['code'] != 200) {
      throw Exception(body['message']?.toString() ?? '接口返回异常');
    }
    return body is Map ? body['data'] : null;
  }

  // ── 用户与权限管理（API 实现）──

  @override
  Future<List<DatabaseUserInfo>> listUsers(DatabaseInstance inst) async {
    throw Exception('1Panel API 不支持用户列表浏览，请通过 SSH 通道查看');
  }

  @override
  Future<void> bindUser(
    DatabaseInstance inst, {
    required String database,
    required String username,
    required String password,
    String permission = '%',
    bool isSuperUser = false,
  }) async {
    if (inst.type.isPostgres) {
      await DatabaseApi.bindPgUser(
        name: inst.name,
        database: database,
        username: username,
        password: password,
        superUser: isSuperUser,
      );
      return;
    }
    await DatabaseApi.bindUser(
      database: inst.name,
      db: database,
      username: username,
      password: password,
      permission: permission,
    );
  }

  @override
  Future<void> changeUserAccess(
    DatabaseInstance inst,
    String username, {
    String permission = '%',
  }) async {
    if (inst.type.isPostgres) {
      throw Exception('PG 修改访问权限请使用超级权限开关');
    }
    await DatabaseApi.changeAccess(
      id: 0,
      from: inst.isRemote ? 'remote' : 'local',
      type: inst.type.apiType,
      database: inst.name,
      value: permission,
    );
  }

  @override
  Future<void> changeUserPassword(
    DatabaseInstance inst,
    String username,
    String newPassword,
  ) async {
    if (inst.type.isPostgres) {
      await DatabaseApi.changePgPassword(
        name: inst.name,
        database: inst.name,
        username: username,
        value: newPassword,
      );
      return;
    }
    await DatabaseApi.changePassword(
      id: inst.apiId,
      from: inst.isRemote ? 'remote' : 'local',
      type: inst.type.apiType,
      database: inst.name,
      value: DatabaseApi.encodeValue(newPassword),
    );
  }

  @override
  Future<void> deleteUser(DatabaseInstance inst, String username) async {
    throw Exception('1Panel API 不支持删除数据库用户，请通过 SSH 通道操作');
  }

  @override
  Future<void> changeUserSuperUser(
    DatabaseInstance inst,
    String username, {
    required bool isSuperUser,
    required String database,
  }) async {
    if (!inst.type.isPostgres) {
      throw Exception('仅 PostgreSQL 支持超级权限切换');
    }
    await DatabaseApi.changePgPrivileges(
      name: inst.name,
      database: database,
      username: username,
      superUser: isSuperUser,
    );
  }
}

/// API First, SSH Fallback：面板实例优先 API，失败或手动实例走 SSH。
class FallbackDatabaseService implements DatabaseService {
  final ApiDatabaseService _api;
  final SshDatabaseService? _ssh;

  FallbackDatabaseService({this._ssh}) : _api = ApiDatabaseService();

  bool get _canSsh => _ssh != null;

  @override
  Future<List<DatabaseInstance>> listInstances() async {
    if (!_canSsh) return _api.listInstances();
    try {
      return await _api.listInstances();
    } catch (_) {
      return _ssh!.listInstances();
    }
  }

  @override
  Future<DatabaseCheckDto> checkInstalled(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.checkInstalled(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.checkInstalled(inst);
    return const DatabaseCheckDto();
  }

  @override
  Future<List<DatabaseItem>> searchDatabases(
    DatabaseInstance inst, {
    int page = 1,
    int pageSize = 100,
    String info = '',
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        return await _api.searchDatabases(
          inst,
          page: page,
          pageSize: pageSize,
          info: info,
        );
      } catch (_) {}
    }
    if (_canSsh) {
      return _ssh!.searchDatabases(
        inst,
        page: page,
        pageSize: pageSize,
        info: info,
      );
    }
    throw Exception('无可用的连接方式（API 不可用且 SSH 未连接）');
  }

  @override
  Future<List<FormatCollationOption>> getFormatOptions(
    DatabaseInstance inst,
  ) async {
    if (inst.fromApi) {
      try {
        return await _api.getFormatOptions(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getFormatOptions(inst);
    return const [];
  }

  @override
  Future<void> createDatabase(
    DatabaseInstance inst,
    String name, {
    String format = '',
    String collation = '',
  }) async {
    if (inst.fromApi) {
      try {
        await _api.createDatabase(
          inst,
          name,
          format: format,
          collation: collation,
        );
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.createDatabase(
        inst,
        name,
        format: format,
        collation: collation,
      );
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> deleteDatabase(
    DatabaseInstance inst,
    DatabaseItem item, {
    bool forceDelete = false,
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        await _api.deleteDatabase(inst, item, forceDelete: forceDelete);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.deleteDatabase(inst, item, forceDelete: forceDelete);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changePassword(DatabaseInstance inst, String newPassword) async {
    if (inst.fromApi) {
      try {
        await _api.changePassword(inst, newPassword);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changePassword(inst, newPassword);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changeAccess(DatabaseInstance inst, String value) async {
    if (inst.fromApi) {
      try {
        await _api.changeAccess(inst, value);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changeAccess(inst, value);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<bool> getRemoteAccess(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.getRemoteAccess(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getRemoteAccess(inst);
    return false;
  }

  @override
  Future<void> updateRemoteAccess(DatabaseInstance inst, bool remote) async {
    if (inst.fromApi) {
      try {
        await _api.updateRemoteAccess(inst, remote);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateRemoteAccess(inst, remote);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> loadFromRemote(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        await _api.loadFromRemote(inst);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.loadFromRemote(inst);
      return;
    }
  }

  @override
  Future<void> loadPgFromRemote(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        await _api.loadPgFromRemote(inst);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.loadPgFromRemote(inst);
      return;
    }
  }

  @override
  Future<Map<String, String>> getStatus(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.getStatus(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getStatus(inst);
    return const {};
  }

  @override
  Future<String> loadConfigFile(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.loadConfigFile(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.loadConfigFile(inst);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> updateConfigFile(DatabaseInstance inst, String file) async {
    if (inst.fromApi) {
      try {
        await _api.updateConfigFile(inst, file);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateConfigFile(inst, file);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<MysqlVariables> loadVariables(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.loadVariables(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.loadVariables(inst);
    return const MysqlVariables();
  }

  @override
  Future<void> updateVariables(
    DatabaseInstance inst,
    List<Map<String, dynamic>> variables,
  ) async {
    if (inst.fromApi) {
      try {
        await _api.updateVariables(inst, variables);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateVariables(inst, variables);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<Map<String, String>> getRedisStatus(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.getRedisStatus(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getRedisStatus(inst);
    return const {};
  }

  @override
  Future<RedisConfDto> getRedisConf(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.getRedisConf(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getRedisConf(inst);
    return const RedisConfDto();
  }

  @override
  Future<void> updateRedisConf(
    DatabaseInstance inst, {
    required String timeout,
    required String maxclients,
    required String maxmemory,
  }) async {
    if (inst.fromApi) {
      try {
        await _api.updateRedisConf(
          inst,
          timeout: timeout,
          maxclients: maxclients,
          maxmemory: maxmemory,
        );
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateRedisConf(
        inst,
        timeout: timeout,
        maxclients: maxclients,
        maxmemory: maxmemory,
      );
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changeRedisPassword(DatabaseInstance inst, String value) async {
    if (inst.fromApi) {
      try {
        await _api.changeRedisPassword(inst, value);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changeRedisPassword(inst, value);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<RedisPersistenceDto> getRedisPersistence(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.getRedisPersistence(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.getRedisPersistence(inst);
    return const RedisPersistenceDto();
  }

  @override
  Future<void> updateRedisAofPersistence(
    DatabaseInstance inst, {
    required String appendonly,
    required String appendfsync,
  }) async {
    if (inst.fromApi) {
      try {
        await _api.updateRedisAofPersistence(
          inst,
          appendonly: appendonly,
          appendfsync: appendfsync,
        );
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateRedisAofPersistence(
        inst,
        appendonly: appendonly,
        appendfsync: appendfsync,
      );
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> updateRedisRdbPersistence(
    DatabaseInstance inst, {
    required String save,
  }) async {
    if (inst.fromApi) {
      try {
        await _api.updateRedisRdbPersistence(inst, save: save);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.updateRedisRdbPersistence(inst, save: save);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<String?> testConnection(DatabaseInstance inst) async {
    if (inst.fromApi) {
      final err = await _api.testConnection(inst);
      if (err == null) return null;
    }
    if (_canSsh) return _ssh!.testConnection(inst);
    return '无可用的连接方式';
  }

  // ── 用户与权限管理（Fallback）──

  @override
  Future<List<DatabaseUserInfo>> listUsers(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.listUsers(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.listUsers(inst);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> bindUser(
    DatabaseInstance inst, {
    required String database,
    required String username,
    required String password,
    String permission = '%',
    bool isSuperUser = false,
  }) async {
    if (inst.fromApi) {
      try {
        await _api.bindUser(
          inst,
          database: database,
          username: username,
          password: password,
          permission: permission,
          isSuperUser: isSuperUser,
        );
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.bindUser(
        inst,
        database: database,
        username: username,
        password: password,
        permission: permission,
        isSuperUser: isSuperUser,
      );
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changeUserAccess(
    DatabaseInstance inst,
    String username, {
    String permission = '%',
  }) async {
    if (inst.fromApi) {
      try {
        await _api.changeUserAccess(inst, username, permission: permission);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changeUserAccess(inst, username, permission: permission);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changeUserPassword(
    DatabaseInstance inst,
    String username,
    String newPassword,
  ) async {
    if (inst.fromApi) {
      try {
        await _api.changeUserPassword(inst, username, newPassword);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changeUserPassword(inst, username, newPassword);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> deleteUser(DatabaseInstance inst, String username) async {
    if (inst.fromApi) {
      try {
        await _api.deleteUser(inst, username);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.deleteUser(inst, username);
      return;
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> changeUserSuperUser(
    DatabaseInstance inst,
    String username, {
    required bool isSuperUser,
    required String database,
  }) async {
    if (inst.fromApi) {
      try {
        await _api.changeUserSuperUser(
          inst,
          username,
          isSuperUser: isSuperUser,
          database: database,
        );
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.changeUserSuperUser(
        inst,
        username,
        isSuperUser: isSuperUser,
        database: database,
      );
      return;
    }
    throw Exception('无可用的连接方式');
  }
}
