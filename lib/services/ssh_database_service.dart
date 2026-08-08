import 'dart:convert';

import '../models/database.dart';
import 'database_service.dart';
import 'ssh_command_service.dart';

/// SSH 实现：在服务器上用实例凭据执行数据库命令。
class SshDatabaseService implements DatabaseService {
  final SshCommandService _ssh;

  SshDatabaseService(this._ssh);

  @override
  Future<List<DatabaseInstance>> listInstances() async {
    // 通过 SSH 探测常见数据库容器，构建候选实例。
    final out = await _ssh.execute(
      'docker ps --format \'{{.Names}} {{.Image}}\' 2>/dev/null',
      timeout: const Duration(seconds: 10),
    );
    final list = <DatabaseInstance>[];
    if (!out.isSuccess) return list;
    final seen = <String>{};
    for (final line in out.stdout.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final name = parts[0];
      final image = parts[1].toLowerCase();
      final DbType? type = image.contains('mariadb')
          ? DbType.mariadb
          : image.contains('mysql')
          ? DbType.mysql
          : image.contains('postgres')
          ? DbType.postgresql
          : image.contains('redis')
          ? DbType.redis
          : image.contains('mongo')
          ? DbType.mongodb
          : null;
      if (type == null || !seen.add(name)) continue;
      list.add(
        DatabaseInstance(
          id: 'ssh_$name',
          type: type,
          name: name,
          containerName: name,
          inDocker: true,
          source: 'manual',
        ),
      );
    }
    return list;
  }

  @override
  Future<DatabaseCheckDto> checkInstalled(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      'docker ps --format \'{{.Names}}\' 2>/dev/null | grep -iE '
      "'${_typePattern(inst.type)}' | head -1",
      timeout: const Duration(seconds: 10),
    );
    final name = r.stdout.trim();
    return DatabaseCheckDto(
      isExist: name.isNotEmpty,
      name: name,
      app: inst.type.apiType,
      version: '',
      status: name.isNotEmpty ? 'Running' : 'NotExist',
    );
  }

  @override
  Future<List<DatabaseItem>> searchDatabases(
    DatabaseInstance inst, {
    int page = 1,
    int pageSize = 100,
    String info = '',
  }) async {
    final cmd = switch (inst.type) {
      DbType.mysql || DbType.mariadb => _buildCli(inst, 'SHOW DATABASES'),
      DbType.postgresql => _buildCli(inst, 'SELECT datname FROM pg_database'),
      DbType.redis => _buildCli(inst, 'CONFIG GET databases'),
      DbType.mongodb => _buildCli(
        inst,
        'db.adminCommand({listDatabases:1}).databases.map(d=>d.name).join("\\n")',
      ),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 12));
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '命令执行失败' : r.stderr);
    }
    if (inst.type.isRedis) {
      final match = RegExp(r'\d+').firstMatch(r.stdout);
      final count = match != null ? int.tryParse(match.group(0)!) ?? 16 : 16;
      return List.generate(
        count,
        (i) => DatabaseItem(name: 'db$i', from: 'local'),
      );
    }
    final items = <DatabaseItem>[];
    for (final line in r.stdout.split('\n')) {
      final name = line.trim();
      if (name.isEmpty || name == 'databases') continue;
      if (_isSystemDb(inst.type, name)) continue;
      items.add(DatabaseItem(name: name, from: 'local'));
    }
    // 简单分页：SSH 全量返回后本地切片。
    final start = (page - 1) * pageSize;
    if (start >= items.length) return const [];
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  @override
  Future<List<FormatCollationOption>> getFormatOptions(
    DatabaseInstance inst,
  ) async {
    if (!inst.type.isPostgres) return const [];
    final r = await _ssh.execute(
      _buildCli(inst, 'SHOW COLLATION'),
      timeout: const Duration(seconds: 10),
    );
    final collations = r.stdout
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return [FormatCollationOption(format: 'utf8', collations: collations)];
  }

  @override
  Future<void> createDatabase(
    DatabaseInstance inst,
    String name, {
    String format = '',
    String collation = '',
  }) async {
    final clause = switch (inst.type) {
      DbType.mysql || DbType.mariadb =>
        format.isNotEmpty
            ? ' CHARACTER SET $format${collation.isNotEmpty ? ' COLLATE $collation' : ''}'
            : '',
      DbType.postgresql =>
        format.isNotEmpty
            ? ' ENCODING \'$format\'${collation.isNotEmpty ? ' LC_COLLATE \'$collation\'' : ''}'
            : '',
      _ => '',
    };
    final cmd = switch (inst.type) {
      DbType.mysql ||
      DbType.mariadb => _buildCli(inst, 'CREATE DATABASE `$name`$clause'),
      DbType.postgresql => _buildCli(inst, 'CREATE DATABASE "$name"$clause'),
      DbType.mongodb => _buildCli(
        inst,
        "db.getSiblingDB('$name').createCollection('_init')",
      ),
      DbType.redis => throw Exception('Redis 无需创建数据库，直接使用 db0-db15'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '创建失败' : r.stderr);
    }
  }

  @override
  Future<void> deleteDatabase(
    DatabaseInstance inst,
    DatabaseItem item, {
    bool forceDelete = false,
  }) async {
    final name = item.instanceName.isNotEmpty ? item.instanceName : item.name;
    final cmd = switch (inst.type) {
      DbType.mysql ||
      DbType.mariadb => _buildCli(inst, 'DROP DATABASE `$name`'),
      DbType.postgresql => _buildCli(inst, 'DROP DATABASE "$name"'),
      DbType.mongodb => _buildCli(
        inst,
        "db.getSiblingDB('$name').dropDatabase()",
      ),
      DbType.redis => throw Exception('Redis 使用 FLUSHDB 清空，无法删除'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '删除失败' : r.stderr);
    }
  }

  @override
  Future<void> changePassword(DatabaseInstance inst, String newPassword) async {
    final cmd = switch (inst.type) {
      DbType.mysql || DbType.mariadb => _buildCli(
        inst,
        "ALTER USER '${inst.username}'@'%' IDENTIFIED BY '$newPassword'; "
        "FLUSH PRIVILEGES",
      ),
      DbType.postgresql => _buildCli(
        inst,
        "ALTER USER \"${inst.username}\" WITH PASSWORD '$newPassword'",
      ),
      DbType.redis => _buildCli(inst, 'CONFIG SET requirepass "$newPassword"'),
      DbType.mongodb => throw Exception('MongoDB 修改密码请通过 SSH 终端操作'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '修改失败' : r.stderr);
    }
  }

  @override
  Future<void> changeAccess(DatabaseInstance inst, String value) async {
    final cmd = switch (inst.type) {
      DbType.mysql || DbType.mariadb => _buildCli(
        inst,
        "UPDATE mysql.user SET host='$value' WHERE user='${inst.username}'; "
        "FLUSH PRIVILEGES",
      ),
      _ => throw Exception('当前数据库类型不支持修改访问权限'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '修改失败' : r.stderr);
    }
  }

  @override
  Future<bool> getRemoteAccess(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      _buildCli(
        inst,
        "SELECT host FROM mysql.user WHERE user='${inst.username}'",
      ),
      timeout: const Duration(seconds: 10),
    );
    return r.stdout.split('\n').map((e) => e.trim()).any((e) => e == '%');
  }

  @override
  Future<void> updateRemoteAccess(DatabaseInstance inst, bool remote) =>
      changeAccess(inst, remote ? '%' : 'localhost');

  @override
  Future<void> loadFromRemote(DatabaseInstance inst) async {
    // SSH 模式下实例与服务器直接对齐，无需同步。
  }

  @override
  Future<void> loadPgFromRemote(DatabaseInstance inst) async {
    // SSH 模式下实例与服务器直接对齐，无需同步。
  }

  @override
  Future<Map<String, String>> getStatus(DatabaseInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.redis => _buildCli(inst, 'INFO server'),
      _ => _buildCli(inst, 'SELECT VERSION()'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    return {'raw': r.stdout.trim()};
  }

  @override
  Future<String> loadConfigFile(DatabaseInstance inst) =>
      throw Exception('SSH 模式暂不支持配置文件读取');

  @override
  Future<void> updateConfigFile(DatabaseInstance inst, String file) =>
      throw Exception('SSH 模式暂不支持配置文件写入');

  @override
  Future<MysqlVariables> loadVariables(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      _buildCli(inst, 'SHOW VARIABLES'),
      timeout: const Duration(seconds: 12),
    );
    final map = <String, dynamic>{};
    for (final line in r.stdout.split('\n')) {
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 2) map[parts[0]] = parts[1];
    }
    return MysqlVariables.fromJson(map);
  }

  @override
  Future<void> updateVariables(
    DatabaseInstance inst,
    List<Map<String, dynamic>> variables,
  ) async {
    final sets = variables
        .map((v) => "SET GLOBAL ${v['key']}='${v['value']}'")
        .join('; ');
    final r = await _ssh.execute(
      _buildCli(inst, '$sets; FLUSH PRIVILEGES'),
      timeout: const Duration(seconds: 12),
    );
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '更新失败' : r.stderr);
    }
  }

  @override
  Future<Map<String, String>> getRedisStatus(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      _buildCli(inst, 'INFO'),
      timeout: const Duration(seconds: 10),
    );
    return _parseRedisInfo(r.stdout);
  }

  @override
  Future<RedisConfDto> getRedisConf(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      _buildCli(inst, 'CONFIG GET maxclients maxmemory timeout requirepass'),
      timeout: const Duration(seconds: 10),
    );
    final lines = r.stdout.split('\n').map((e) => e.trim()).toList();
    String val(List<String> l, String key, String fallback) {
      for (var i = 0; i + 1 < l.length; i += 2) {
        if (l[i] == key) return l[i + 1];
      }
      return fallback;
    }

    return RedisConfDto(
      maxclients: val(lines, 'maxclients', '10000'),
      maxmemory: val(lines, 'maxmemory', '0'),
      timeout: val(lines, 'timeout', '0'),
      requirepass: val(lines, 'requirepass', ''),
      port: inst.port.toString(),
    );
  }

  @override
  Future<void> updateRedisConf(
    DatabaseInstance inst, {
    required String timeout,
    required String maxclients,
    required String maxmemory,
  }) async {
    final r = await _ssh.execute(
      _buildCli(
        inst,
        'CONFIG SET timeout "$timeout" maxclients "$maxclients" '
        'maxmemory "$maxmemory"',
      ),
      timeout: const Duration(seconds: 10),
    );
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '更新失败' : r.stderr);
    }
  }

  @override
  Future<void> changeRedisPassword(DatabaseInstance inst, String value) async {
    final decoded = _b64decode(value);
    final r = await _ssh.execute(
      _buildCli(inst, 'CONFIG SET requirepass "$decoded"'),
      timeout: const Duration(seconds: 10),
    );
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '修改失败' : r.stderr);
    }
  }

  @override
  Future<RedisPersistenceDto> getRedisPersistence(DatabaseInstance inst) async {
    final r = await _ssh.execute(
      _buildCli(inst, 'CONFIG GET appendonly save appendfsync'),
      timeout: const Duration(seconds: 10),
    );
    final lines = r.stdout.split('\n').map((e) => e.trim()).toList();
    String val(List<String> l, String key, String fallback) {
      for (var i = 0; i + 1 < l.length; i += 2) {
        if (l[i] == key) return l[i + 1];
      }
      return fallback;
    }

    return RedisPersistenceDto(
      aofEnabled: val(lines, 'appendonly', 'no'),
      appendfsync: val(lines, 'appendfsync', 'everysec'),
      save: val(lines, 'save', ''),
    );
  }

  @override
  Future<void> updateRedisAofPersistence(
    DatabaseInstance inst, {
    required String appendonly,
    required String appendfsync,
  }) async {
    final r = await _ssh.execute(
      _buildCli(
        inst,
        'CONFIG SET appendonly "$appendonly" appendfsync "$appendfsync"',
      ),
      timeout: const Duration(seconds: 10),
    );
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '更新失败' : r.stderr);
    }
  }

  @override
  Future<void> updateRedisRdbPersistence(
    DatabaseInstance inst, {
    required String save,
  }) async {
    final r = await _ssh.execute(
      _buildCli(inst, 'CONFIG SET save "$save"'),
      timeout: const Duration(seconds: 10),
    );
    if (!r.isSuccess) {
      throw Exception(r.stderr.isEmpty ? '更新失败' : r.stderr);
    }
  }

  @override
  Future<String?> testConnection(DatabaseInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.mysql || DbType.mariadb => _buildCli(inst, 'SELECT 1'),
      DbType.postgresql => _buildCli(inst, 'SELECT 1'),
      DbType.redis => _buildCli(inst, 'PING'),
      DbType.mongodb => _buildCli(inst, 'db.runCommand({ping:1}).ok'),
    };
    try {
      final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
      if (r.isSuccess &&
          (r.stdout.contains('1') || r.stdout.contains('PONG'))) {
        return null;
      }
      return r.stderr.isEmpty ? '连接失败' : r.stderr;
    } catch (e) {
      return '$e';
    }
  }

  static String _typePattern(DbType type) => switch (type) {
    DbType.mysql => 'mysql|maria',
    DbType.mariadb => 'maria',
    DbType.postgresql => 'postgres',
    DbType.redis => 'redis',
    DbType.mongodb => 'mongo',
  };

  static String _b64decode(String value) {
    try {
      return utf8.decode(base64Decode(value));
    } catch (_) {
      return value;
    }
  }

  static Map<String, String> _parseRedisInfo(String raw) {
    final map = <String, String>{};
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final idx = t.indexOf(':');
      if (idx <= 0) continue;
      map[t.substring(0, idx)] = t.substring(idx + 1);
    }
    return map;
  }

  bool _isSystemDb(DbType type, String name) {
    if (type == DbType.mysql || type == DbType.mariadb) {
      return name == 'mysql' ||
          name == 'sys' ||
          name == 'information_schema' ||
          name == 'performance_schema';
    }
    if (type == DbType.postgresql) {
      return name == 'postgres' ||
          name.startsWith('template') ||
          name.startsWith('pg_');
    }
    return false;
  }

  /// 构造连接参数：本机不加 -h/-P，远程加，Docker 容器用 docker exec。
  String _buildCli(DatabaseInstance inst, String innerCmd) {
    final user = inst.username;
    final pass = inst.password ?? '';
    final escapedPass = pass.replaceAll("'", "'\\''");

    if (inst.inDocker && inst.containerName != null) {
      final env = switch (inst.type) {
        DbType.mysql || DbType.mariadb => "MYSQL_PWD='$escapedPass'",
        DbType.postgresql => "PGPASSWORD='$escapedPass'",
        _ => '',
      };
      final inner = _cliInner(inst, user, '$env', innerCmd, insideDocker: true);
      return "docker exec ${inst.containerName} sh -c '$inner'";
    }

    final env = switch (inst.type) {
      DbType.mysql || DbType.mariadb => "MYSQL_PWD='$escapedPass'",
      DbType.postgresql => "PGPASSWORD='$escapedPass'",
      _ => '',
    };
    return _cliInner(inst, user, env, innerCmd, insideDocker: false);
  }

  String _cliInner(
    DatabaseInstance inst,
    String user,
    String env,
    String innerCmd, {
    required bool insideDocker,
  }) {
    final isLocal =
        inst.address.isEmpty ||
        inst.address == 'localhost' ||
        inst.address == '127.0.0.1';
    final hostArg = !isLocal && !insideDocker
        ? ' -h ${inst.address} -P ${inst.port}'
        : '';

    switch (inst.type) {
      case DbType.mysql || DbType.mariadb:
        final mpass = inst.password?.replaceAll("'", "'\\''");
        return 'C="\$(docker ps --format \'{{.Names}}\' 2>/dev/null | grep -iE \'mysql|maria\' | head -1)"; '
            'if [ -n "\$C" ]; then '
            "docker exec \"\$C\" sh -c 'U=\"\\\${MYSQL_USER:-\$user}\"; MYSQL_PWD=\"$mpass\" mysql -u\"\$U\" -e \"\$innerCmd\" -N'; "
            'else M="\$(command -v mysql || find /usr/bin /usr/local/bin -name mysql 2>/dev/null | head -1)"; '
            "if [ -n \"\$M\" ]; then MYSQL_PWD=\"$mpass\" \"\$M\" -u$user$hostArg -e \"$innerCmd\" -N; "
            'else echo "mysql not found"; fi; fi';
      case DbType.postgresql:
        final ppass = inst.password?.replaceAll("'", "'\\''");
        return 'C="\$(docker ps --format \'{{.Names}}\' 2>/dev/null | grep -i postgres | head -1)"; '
            'if [ -n "\$C" ]; then '
            "docker exec \"\$C\" sh -c 'U=\"\\\${POSTGRES_USER:-\$user}\"; PGPASSWORD=\"$ppass\" psql -U \"\$U\" -c \"\$innerCmd\" -t -A'; "
            'else P="\$(command -v psql || find /usr/lib/postgresql -name psql 2>/dev/null | tail -1)"; '
            "if [ -n \"\$P\" ]; then PGPASSWORD=\"$ppass\" \"\$P\" -U $user$hostArg -c \"$innerCmd\" -t -A; "
            'else echo "psql not found"; fi; fi';
      case DbType.redis:
        final auth = inst.password != null && inst.password!.isNotEmpty
            ? " -a '${inst.password}' --no-auth-warning"
            : '';
        return 'redis-cli$hostArg$auth $innerCmd';
      case DbType.mongodb:
        final auth = inst.password != null && inst.password!.isNotEmpty
            ? " -u $user -p '${inst.password}'"
            : '';
        return 'mongosh$hostArg$auth --quiet --eval "$innerCmd"';
    }
  }
}
