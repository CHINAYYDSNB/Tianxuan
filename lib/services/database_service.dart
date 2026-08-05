import '../api/database_api.dart';
import '../models/database.dart';
import 'ssh_command_service.dart';

/// 数据库操作服务抽象。
/// 实例信息（凭据）来自本地保存；操作优先 API，失败 fallback SSH。
abstract class DatabaseService {
  Future<List<DatabaseItem>> listDatabases(DatabaseInstance inst);

  Future<void> createDatabase(DatabaseInstance inst, String name);

  Future<void> deleteDatabase(DatabaseInstance inst, String name);

  Future<void> changePassword(DatabaseInstance inst, String newPassword);

  /// 返回 null 表示连接成功，否则返回错误信息
  Future<String?> testConnection(DatabaseInstance inst);

  Future<Map<String, String>> getStatus(DatabaseInstance inst);
}

/// 1Panel API 实现（仅面板登记实例可用）
class ApiDatabaseService implements DatabaseService {
  @override
  Future<List<DatabaseItem>> listDatabases(DatabaseInstance inst) =>
      DatabaseApi.searchDatabases(inst);

  @override
  Future<void> createDatabase(DatabaseInstance inst, String name) =>
      DatabaseApi.createDatabase(inst, name);

  @override
  Future<void> deleteDatabase(DatabaseInstance inst, String name) =>
      DatabaseApi.deleteDatabase(inst, name);

  @override
  Future<void> changePassword(DatabaseInstance inst, String newPassword) =>
      DatabaseApi.changePassword(inst, newPassword: newPassword);

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

  @override
  Future<Map<String, String>> getStatus(DatabaseInstance inst) =>
      DatabaseApi.getStatus(inst);
}

/// SSH 实现：在服务器上用实例凭据执行数据库命令
class SshDatabaseService implements DatabaseService {
  final SshCommandService _ssh;

  SshDatabaseService(this._ssh);

  /// 构造连接参数：本机不加 -h/-P，远程加，Docker 容器用 docker exec
  String _buildCli(DatabaseInstance inst, String innerCmd) {
    final user = inst.username;
    final pass = inst.password ?? '';
    final escapedPass = pass.replaceAll("'", "'\\''");

    // Docker 容器：docker exec 注入环境变量密码
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
        // 优先检测 mysql/maria 容器（docker exec，容器内 MYSQL_USER 优先）；
        // 无容器则宿主动态查找 mysql
        final mpass = inst.password?.replaceAll("'", "'\\''");
        return 'C="\$(docker ps --format \'{{.Names}}\' 2>/dev/null | grep -iE \'mysql|maria\' | head -1)"; '
            'if [ -n "\$C" ]; then '
            "docker exec \"\$C\" sh -c 'U=\"\\\${MYSQL_USER:-\$user}\"; MYSQL_PWD=\"$mpass\" mysql -u\"\$U\" -e \"\$innerCmd\" -N'; "
            'else M="\$(command -v mysql || find /usr/bin /usr/local/bin -name mysql 2>/dev/null | head -1)"; '
            "if [ -n \"\$M\" ]; then MYSQL_PWD=\"$mpass\" \"\$M\" -u$user$hostArg -e \"$innerCmd\" -N; "
            'else echo "mysql not found"; fi; fi';
      case DbType.postgresql:
        // 优先检测 postgres 容器（docker exec，容器内 POSTGRES_USER 优先）；
        // 无容器则宿主动态查找 psql
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

  @override
  Future<List<DatabaseItem>> listDatabases(DatabaseInstance inst) async {
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
    if (!r.isSuccess) throw Exception(r.stderr.isEmpty ? '命令执行失败' : r.stderr);

    // Redis：解析 CONFIG GET databases 返回的数量，生成 db0..dbN
    if (inst.type == DbType.redis) {
      final match = RegExp(r'\d+').firstMatch(r.stdout);
      final count = match != null ? int.tryParse(match.group(0)!) ?? 16 : 16;
      return List.generate(count, (i) => DatabaseItem(name: 'db$i'));
    }

    final items = <DatabaseItem>[];
    for (final line in r.stdout.split('\n')) {
      final name = line.trim();
      if (name.isEmpty) continue;
      // 过滤系统库
      if (_isSystemDb(inst.type, name)) continue;
      if (inst.type == DbType.redis && name == 'databases') continue;
      items.add(DatabaseItem(name: name));
    }
    return items;
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

  @override
  Future<void> createDatabase(DatabaseInstance inst, String name) async {
    final cmd = switch (inst.type) {
      DbType.mysql ||
      DbType.mariadb => _buildCli(inst, 'CREATE DATABASE `$name`'),
      DbType.postgresql => _buildCli(inst, 'CREATE DATABASE "$name"'),
      DbType.mongodb => _buildCli(
        inst,
        "db.getSiblingDB('$name').createCollection('_init')",
      ),
      DbType.redis => throw Exception('Redis 无需创建数据库，直接使用 db0-db15'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    if (!r.isSuccess) throw Exception(r.stderr.isEmpty ? '创建失败' : r.stderr);
  }

  @override
  Future<void> deleteDatabase(DatabaseInstance inst, String name) async {
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
    if (!r.isSuccess) throw Exception(r.stderr.isEmpty ? '删除失败' : r.stderr);
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
    if (!r.isSuccess) throw Exception(r.stderr.isEmpty ? '修改失败' : r.stderr);
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

  @override
  Future<Map<String, String>> getStatus(DatabaseInstance inst) async {
    final cmd = switch (inst.type) {
      DbType.redis => _buildCli(inst, 'INFO server'),
      _ => _buildCli(inst, 'SELECT VERSION()'),
    };
    final r = await _ssh.execute(cmd, timeout: const Duration(seconds: 10));
    return {'raw': r.stdout.trim()};
  }
}

/// API First, SSH Fallback：面板实例优先 API，失败或手动实例走 SSH
class FallbackDatabaseService implements DatabaseService {
  final ApiDatabaseService _api;
  final SshDatabaseService? _ssh;

  FallbackDatabaseService({SshDatabaseService? ssh})
    : _api = ApiDatabaseService(),
      _ssh = ssh;

  bool get _canSsh => _ssh != null;

  @override
  Future<List<DatabaseItem>> listDatabases(DatabaseInstance inst) async {
    if (inst.fromApi) {
      try {
        return await _api.listDatabases(inst);
      } catch (_) {}
    }
    if (_canSsh) return _ssh!.listDatabases(inst);
    throw Exception('无可用连接方式（API 不可用且 SSH 未连接）');
  }

  @override
  Future<void> createDatabase(DatabaseInstance inst, String name) async {
    if (inst.fromApi) {
      try {
        await _api.createDatabase(inst, name);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.createDatabase(inst, name);
      return;
    }
    throw Exception('无可用连接方式');
  }

  @override
  Future<void> deleteDatabase(DatabaseInstance inst, String name) async {
    if (inst.fromApi) {
      try {
        await _api.deleteDatabase(inst, name);
        return;
      } catch (_) {}
    }
    if (_canSsh) {
      await _ssh!.deleteDatabase(inst, name);
      return;
    }
    throw Exception('无可用连接方式');
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
    throw Exception('无可用连接方式');
  }

  @override
  Future<String?> testConnection(DatabaseInstance inst) async {
    if (inst.fromApi) {
      final err = await _api.testConnection(inst);
      if (err == null) return null;
    }
    if (_canSsh) return _ssh!.testConnection(inst);
    return '无可用连接方式';
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
}
