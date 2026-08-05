/// 数据库类型
enum DbType { mysql, mariadb, postgresql, mongodb, redis }

extension DbTypeMeta on DbType {
  String get label => switch (this) {
    DbType.mysql => 'MySQL',
    DbType.mariadb => 'MariaDB',
    DbType.postgresql => 'PostgreSQL',
    DbType.mongodb => 'MongoDB',
    DbType.redis => 'Redis',
  };

  /// 1Panel API 的类型名（导入列表用，逗号分隔）
  String get apiType => switch (this) {
    DbType.mysql => 'mysql',
    DbType.mariadb => 'mariadb',
    DbType.postgresql => 'postgresql',
    DbType.mongodb => 'mongodb',
    DbType.redis => 'redis',
  };

  /// 数据库实例组合类型（1Panel GET /databases/db/list/{types}）
  static const apiListTypes =
      'mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster';

  int get defaultPort => switch (this) {
    DbType.mysql => 3306,
    DbType.mariadb => 3306,
    DbType.postgresql => 5432,
    DbType.mongodb => 27017,
    DbType.redis => 6379,
  };

  String get defaultUser => switch (this) {
    DbType.mysql => 'root',
    DbType.mariadb => 'root',
    DbType.postgresql => 'postgres',
    DbType.mongodb => 'admin',
    DbType.redis => 'default',
  };

  static DbType? fromString(String? s) {
    if (s == null || s.isEmpty) return null;
    final v = s.toLowerCase();
    if (v.contains('mysql') || v.contains('maria')) return DbType.mysql;
    if (v.contains('postgres')) return DbType.postgresql;
    if (v.contains('mongo')) return DbType.mongodb;
    if (v.contains('redis')) return DbType.redis;
    return null;
  }
}

/// 数据库实例（本地持久化，密码单独加密存储）
class DatabaseInstance {
  final String id;
  final DbType type;
  final String name;

  /// 连接地址：服务器本机为 localhost / 127.0.0.1
  final String address;
  final int port;
  final String username;
  final String? password;
  final String version;
  final String? containerName;

  /// 来源：manual（手动添加）| api（从 1Panel 导入）
  final String source;

  final bool inDocker;

  const DatabaseInstance({
    required this.id,
    required this.type,
    required this.name,
    this.address = 'localhost',
    this.port = 3306,
    this.username = 'root',
    this.password,
    this.version = '',
    this.containerName,
    this.source = 'manual',
    this.inDocker = false,
  });

  bool get fromApi => source == 'api';

  /// 展示地址
  String get displayAddress => inDocker && containerName != null
      ? 'Docker: $containerName'
      : '$address:$port';

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'address': address,
    'port': port,
    'username': username,
    'version': version,
    'containerName': containerName,
    'source': source,
    'inDocker': inDocker,
  };

  factory DatabaseInstance.fromJson(Map<String, dynamic> json) {
    final type = DbTypeMeta.fromString(json['type'] as String?) ?? DbType.mysql;
    return DatabaseInstance(
      id: json['id'] as String? ?? '',
      type: type,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? 'localhost',
      port: (json['port'] as num?)?.toInt() ?? type.defaultPort,
      username: json['username'] as String? ?? type.defaultUser,
      version: json['version'] as String? ?? '',
      containerName: json['containerName'] as String?,
      source: json['source'] as String? ?? 'manual',
      inDocker: json['inDocker'] as bool? ?? false,
    );
  }

  DatabaseInstance copyWith({String? password, String? version}) {
    return DatabaseInstance(
      id: id,
      type: type,
      name: name,
      address: address,
      port: port,
      username: username,
      password: password ?? this.password,
      version: version ?? this.version,
      containerName: containerName,
      source: source,
      inDocker: inDocker,
    );
  }
}

/// 实例下的数据库项
class DatabaseItem {
  final String name;
  final String format;
  final String collation;
  final String username;
  final String permission;
  final String description;

  const DatabaseItem({
    required this.name,
    this.format = '',
    this.collation = '',
    this.username = '',
    this.permission = '',
    this.description = '',
  });

  factory DatabaseItem.fromJson(Map<String, dynamic> json) {
    return DatabaseItem(
      name: json['name'] as String? ?? json['mysqlName'] as String? ?? '',
      format: json['format'] as String? ?? '',
      collation: json['collation'] as String? ?? '',
      username: json['username'] as String? ?? '',
      permission: json['permission'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// 数据库用户
class DatabaseUser {
  final String name;
  final String host;
  final String grants;

  const DatabaseUser({required this.name, this.host = '', this.grants = ''});

  String get label => host.isEmpty ? name : '$name@$host';
}
