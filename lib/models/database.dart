/// 数据库类型（移植自 Lanxi）
enum DbType { mysql, postgresql, mongodb, redis }

extension DbTypeMeta on DbType {
  String get label => switch (this) {
    DbType.mysql => 'MySQL',
    DbType.postgresql => 'PostgreSQL',
    DbType.mongodb => 'MongoDB',
    DbType.redis => 'Redis',
  };

  String get defaultPort => switch (this) {
    DbType.mysql => '3306',
    DbType.postgresql => '5432',
    DbType.mongodb => '27017',
    DbType.redis => '6379',
  };

  String get defaultUser => switch (this) {
    DbType.mysql => 'root',
    DbType.postgresql => 'postgres',
    DbType.mongodb => 'admin',
    DbType.redis => 'default',
  };

  /// Docker 容器常见环境变量（可能保存密码）
  List<String> get passwordEnvVars => switch (this) {
    DbType.mysql => [
      'MYSQL_ROOT_PASSWORD',
      'MYSQL_PASSWORD',
      'MARIADB_ROOT_PASSWORD',
    ],
    DbType.postgresql => ['POSTGRES_PASSWORD', 'POSTGRES_ROOT_PASSWORD'],
    DbType.mongodb => [
      'MONGO_INITDB_ROOT_PASSWORD',
      'MONGO_INITDB_ROOT_USERNAME',
    ],
    DbType.redis => ['REDIS_PASSWORD', 'REQUIREPASS'],
  };
}

/// 数据库实例（检测结果，含会话级认证信息）
class DbInstance {
  final DbType type;
  final bool inDocker;
  final String? containerName;
  final String? version;
  int? port;
  final String? status;

  // 会话级认证（不持久化）
  String? authUser;
  String? authPass;
  bool authFailed = false;

  DbInstance({
    required this.type,
    this.inDocker = false,
    this.containerName,
    this.version,
    this.port,
    this.status,
    this.authUser,
    this.authPass,
  });

  String get label {
    final v = version ?? '';
    final d = inDocker ? ' [Docker]' : '';
    final n = containerName != null ? ' ($containerName)' : '';
    return '${type.label} $v$d$n';
  }

  String get subtitle {
    final parts = <String>[];
    if (port != null) parts.add('端口: $port');
    if (inDocker) parts.add('容器: $containerName');
    if (status != null) parts.add(status!);
    return parts.join(' · ');
  }

  String get cliCmd => switch (type) {
    DbType.mysql => 'mysql',
    DbType.postgresql => 'psql',
    DbType.mongodb => 'mongosh',
    DbType.redis => 'redis-cli',
  };

  bool get needsAuth => type != DbType.redis || authPass != null;

  /// 连接参数（密码用环境变量 MYSQL_PWD / PGPASSWORD）
  String get connArgs {
    final u = authUser ?? type.defaultUser;
    final buf = StringBuffer();
    if (type == DbType.mysql) {
      buf.write('-u$u');
    } else if (type == DbType.postgresql) {
      buf.write('-U $u');
      if (inDocker) buf.write(' -h localhost');
    } else if (type == DbType.mongodb) {
      buf.write('-u $u');
      if (authPass != null && authPass!.isNotEmpty) {
        buf.write(' -p $authPass --authenticationDatabase admin');
      }
    } else if (type == DbType.redis) {
      if (authPass != null && authPass!.isNotEmpty) {
        buf.write('-a $authPass --no-auth-warning');
      }
    }
    return buf.toString();
  }

  /// 包裹命令（注入密码环境变量 / docker exec）
  String wrapCmd(String cmd) {
    final envs = <String>[];
    final p = authPass;
    if (p != null && p.isNotEmpty) {
      final escapedP = p.replaceAll("'", "'\\''");
      if (type == DbType.mysql) envs.add("MYSQL_PWD='$escapedP'");
      if (type == DbType.postgresql) envs.add("PGPASSWORD='$escapedP'");
    }
    final prefix = envs.isNotEmpty ? '${envs.join(' ')} ' : '';

    if (inDocker && containerName != null) {
      final escaped = cmd.replaceAll("'", "'\\''");
      return 'docker exec $containerName sh -c \'$prefix$escaped\'';
    }
    return '$prefix$cmd';
  }
}

/// 数据库项
class DbDatabase {
  final String name;
  const DbDatabase({required this.name});
}

/// 数据库用户
class DbUser {
  final String name;
  final String? host;
  final String? grants;
  const DbUser({required this.name, this.host, this.grants});
}
