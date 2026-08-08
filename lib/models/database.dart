/// 数据库类型。
enum DbType { mysql, mariadb, postgresql, mongodb, redis }

extension DbTypeMeta on DbType {
  String get label => switch (this) {
    DbType.mysql => 'MySQL',
    DbType.mariadb => 'MariaDB',
    DbType.postgresql => 'PostgreSQL',
    DbType.mongodb => 'MongoDB',
    DbType.redis => 'Redis',
  };

  /// 1Panel API 的类型名（列表接口逗号分隔）。
  String get apiType => switch (this) {
    DbType.mysql => 'mysql',
    DbType.mariadb => 'mariadb',
    DbType.postgresql => 'postgresql',
    DbType.mongodb => 'mongodb',
    DbType.redis => 'redis',
  };

  /// 1Panel GET /databases/db/list/{types} 的完整类型串（含集群）。
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

  bool get isRedis => this == DbType.redis;

  bool get isPostgres => this == DbType.postgresql;

  static DbType? fromString(String? s) {
    if (s == null || s.isEmpty) return null;
    final v = s.toLowerCase();
    if (v.contains('maria')) return DbType.mariadb;
    if (v.contains('mysql')) return DbType.mysql;
    if (v.contains('postgres')) return DbType.postgresql;
    if (v.contains('mongo')) return DbType.mongodb;
    if (v.contains('redis')) return DbType.redis;
    return null;
  }
}

/// 数据库实例（本地持久化，密码单独加密存储）。
///
/// 对齐 Mono-Dash 的实例模型：`apiId` 为 1Panel 记录 id，
/// `from` 为 `local`（面板本机）/ `remote`（远程连接）。
class DatabaseInstance {
  final String id;
  final int apiId;
  final DbType type;
  final String name;

  /// 连接地址：服务器本机为 localhost / 127.0.0.1。
  final String address;
  final int port;
  final String username;
  final String? password;
  final String version;
  final String? containerName;

  /// 来源：manual（手动添加）| api（从 1Panel 导入）。
  final String source;

  /// local（面板本机实例）| remote（远程连接实例）。
  final String from;

  final bool inDocker;

  const DatabaseInstance({
    required this.id,
    this.apiId = 0,
    required this.type,
    required this.name,
    this.address = 'localhost',
    this.port = 3306,
    this.username = 'root',
    this.password,
    this.version = '',
    this.containerName,
    this.source = 'manual',
    this.from = 'local',
    this.inDocker = false,
  });

  bool get fromApi => source == 'api';

  bool get isRemote => from == 'remote';

  String get displayAddress => inDocker && containerName != null
      ? 'Docker: $containerName'
      : '$address:$port';

  Map<String, dynamic> toJson() => {
    'id': id,
    'apiId': apiId,
    'type': type.name,
    'name': name,
    'address': address,
    'port': port,
    'username': username,
    'version': version,
    'containerName': containerName,
    'source': source,
    'from': from,
    'inDocker': inDocker,
  };

  factory DatabaseInstance.fromJson(Map<String, dynamic> json) {
    final type = DbTypeMeta.fromString(json['type'] as String?) ?? DbType.mysql;
    return DatabaseInstance(
      id: json['id'] as String? ?? '',
      apiId: (json['apiId'] as num?)?.toInt() ?? 0,
      type: type,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? 'localhost',
      port: (json['port'] as num?)?.toInt() ?? type.defaultPort,
      username: json['username'] as String? ?? type.defaultUser,
      version: json['version'] as String? ?? '',
      containerName: json['containerName'] as String?,
      source: json['source'] as String? ?? 'manual',
      from: json['from'] as String? ?? 'local',
      inDocker: json['inDocker'] as bool? ?? false,
    );
  }

  DatabaseInstance copyWith({
    String? password,
    String? version,
    int? apiId,
    String? from,
    String? source,
    String? address,
    int? port,
    String? username,
  }) {
    return DatabaseInstance(
      id: id,
      apiId: apiId ?? this.apiId,
      type: type,
      name: name,
      address: address ?? this.address,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      version: version ?? this.version,
      containerName: containerName,
      source: source ?? this.source,
      from: from ?? this.from,
      inDocker: inDocker,
    );
  }
}

/// 实例下的数据库项（对齐 Mono-Dash DatabaseSearchItemDto）。
class DatabaseItem {
  final int id;
  final String createdAt;
  final String name;
  final String from;
  final String mysqlName;
  final String format;
  final String collation;
  final String username;
  final String password;
  final String permission;
  final bool isDelete;
  final String description;
  final String? pgName;
  final bool? superUser;

  const DatabaseItem({
    required this.name,
    this.id = 0,
    this.createdAt = '',
    this.from = 'local',
    this.mysqlName = '',
    this.format = '',
    this.collation = '',
    this.username = '',
    this.password = '',
    this.permission = '',
    this.isDelete = false,
    this.description = '',
    this.pgName,
    this.superUser,
  });

  /// 实例名：PG 优先 postgresqlName，否则 mysqlName。
  String get instanceName =>
      (pgName != null && pgName!.isNotEmpty) ? pgName! : mysqlName;

  factory DatabaseItem.fromJson(Map<String, dynamic> json) {
    final mysqlName =
        json['mysqlName']?.toString() ?? json['name']?.toString() ?? '';
    return DatabaseItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      name: json['name']?.toString() ?? json['mysqlName']?.toString() ?? '',
      from: json['from']?.toString() ?? 'local',
      mysqlName: mysqlName,
      format: json['format']?.toString() ?? '',
      collation: json['collation']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      permission: json['permission']?.toString() ?? '',
      isDelete: json['isDelete'] as bool? ?? false,
      description: json['description']?.toString() ?? '',
      pgName: json['postgresqlName']?.toString(),
      superUser: json['superUser'] as bool?,
    );
  }
}

/// 数据库安装检查结果（对齐 Mono-Dash DatabaseCheckDto）。
class DatabaseCheckDto {
  final bool isExist;
  final String name;
  final String app;
  final String version;
  final String status;
  final String createdAt;
  final String lastBackupAt;
  final int appInstallId;
  final String containerName;
  final String installPath;
  final int httpPort;
  final int httpsPort;
  final String websiteDir;

  const DatabaseCheckDto({
    this.isExist = false,
    this.name = '',
    this.app = '',
    this.version = '',
    this.status = '',
    this.createdAt = '',
    this.lastBackupAt = '',
    this.appInstallId = 0,
    this.containerName = '',
    this.installPath = '',
    this.httpPort = 0,
    this.httpsPort = 0,
    this.websiteDir = '',
  });

  factory DatabaseCheckDto.fromJson(Map<String, dynamic> json) {
    return DatabaseCheckDto(
      isExist: json['isExist'] as bool? ?? false,
      name: json['name']?.toString() ?? '',
      app: json['app']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      lastBackupAt: json['lastBackupAt']?.toString() ?? '',
      appInstallId: (json['appInstallId'] as num?)?.toInt() ?? 0,
      containerName: json['containerName']?.toString() ?? '',
      installPath: json['installPath']?.toString() ?? '',
      httpPort: (json['httpPort'] as num?)?.toInt() ?? 0,
      httpsPort: (json['httpsPort'] as num?)?.toInt() ?? 0,
      websiteDir: json['websiteDir']?.toString() ?? '',
    );
  }
}

/// 删除检查返回的占用资源（对齐 Mono-Dash DBResourceDto）。
class DBResourceDto {
  final String type;
  final String name;

  const DBResourceDto({required this.type, required this.name});

  factory DBResourceDto.fromJson(Map<String, dynamic> json) {
    return DBResourceDto(
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

/// 字符集与排序规则选项（对齐 Mono-Dash FormatCollationOption）。
class FormatCollationOption {
  final String format;
  final List<String> collations;

  const FormatCollationOption({
    required this.format,
    this.collations = const [],
  });

  factory FormatCollationOption.fromJson(Map<String, dynamic> json) {
    return FormatCollationOption(
      format: json['format']?.toString() ?? '',
      collations:
          (json['collations'] as List?)?.whereType<String>().toList() ??
          const [],
    );
  }
}

/// MySQL 性能变量（对齐 Mono-Dash MysqlVariables）。
class MysqlVariables {
  final String? binlogCacheSize;
  final String? innodbBufferPoolSize;
  final String? innodbLogBufferSize;
  final String? joinBufferSize;
  final String? keyBufferSize;
  final String? longQueryTime;
  final String? maxConnections;
  final String? maxHeapTableSize;
  final String? queryCacheSize;
  final String? queryCacheType;
  final String? readBufferSize;
  final String? readRndBufferSize;
  final String? slowQueryLog;
  final String? sortBufferSize;
  final String? tableOpenCache;
  final String? threadCacheSize;
  final String? threadStackSize;
  final String? tmpTableSize;

  const MysqlVariables({
    this.binlogCacheSize,
    this.innodbBufferPoolSize,
    this.innodbLogBufferSize,
    this.joinBufferSize,
    this.keyBufferSize,
    this.longQueryTime,
    this.maxConnections,
    this.maxHeapTableSize,
    this.queryCacheSize,
    this.queryCacheType,
    this.readBufferSize,
    this.readRndBufferSize,
    this.slowQueryLog,
    this.sortBufferSize,
    this.tableOpenCache,
    this.threadCacheSize,
    this.threadStackSize,
    this.tmpTableSize,
  });

  factory MysqlVariables.fromJson(Map<String, dynamic> json) {
    return MysqlVariables(
      binlogCacheSize: json['binlog_cache_size']?.toString(),
      innodbBufferPoolSize: json['innodb_buffer_pool_size']?.toString(),
      innodbLogBufferSize: json['innodb_log_buffer_size']?.toString(),
      joinBufferSize: json['join_buffer_size']?.toString(),
      keyBufferSize: json['key_buffer_size']?.toString(),
      longQueryTime: json['long_query_time']?.toString(),
      maxConnections: json['max_connections']?.toString(),
      maxHeapTableSize: json['max_heap_table_size']?.toString(),
      queryCacheSize: json['query_cache_size']?.toString(),
      queryCacheType: json['query_cache_type']?.toString(),
      readBufferSize: json['read_buffer_size']?.toString(),
      readRndBufferSize: json['read_rnd_buffer_size']?.toString(),
      slowQueryLog: json['slow_query_log']?.toString(),
      sortBufferSize: json['sort_buffer_size']?.toString(),
      tableOpenCache: json['table_open_cache']?.toString(),
      threadCacheSize: json['thread_cache_size']?.toString(),
      threadStackSize: json['thread_stack']?.toString(),
      tmpTableSize: json['tmp_table_size']?.toString(),
    );
  }

  Map<String, String> toMap() {
    final m = <String, String>{};
    void put(String k, String? v) {
      if (v != null) m[k] = v;
    }

    put('binlog_cache_size', binlogCacheSize);
    put('innodb_buffer_pool_size', innodbBufferPoolSize);
    put('innodb_log_buffer_size', innodbLogBufferSize);
    put('join_buffer_size', joinBufferSize);
    put('key_buffer_size', keyBufferSize);
    put('long_query_time', longQueryTime);
    put('max_connections', maxConnections);
    put('max_heap_table_size', maxHeapTableSize);
    put('query_cache_size', queryCacheSize);
    put('query_cache_type', queryCacheType);
    put('read_buffer_size', readBufferSize);
    put('read_rnd_buffer_size', readRndBufferSize);
    put('slow_query_log', slowQueryLog);
    put('sort_buffer_size', sortBufferSize);
    put('table_open_cache', tableOpenCache);
    put('thread_cache_size', threadCacheSize);
    put('thread_stack', threadStackSize);
    put('tmp_table_size', tmpTableSize);
    return m;
  }
}

/// Redis 配置（对齐 Mono-Dash RedisConfDto）。
class RedisConfDto {
  final String maxclients;
  final String maxmemory;
  final String requirepass;
  final String timeout;
  final String port;

  const RedisConfDto({
    this.maxclients = '10000',
    this.maxmemory = '0',
    this.requirepass = '',
    this.timeout = '0',
    this.port = '6379',
  });

  factory RedisConfDto.fromJson(Map<String, dynamic> json) {
    return RedisConfDto(
      maxclients: '${json['maxclients'] ?? '10000'}',
      maxmemory: '${json['maxmemory'] ?? '0'}',
      requirepass: '${json['requirepass'] ?? ''}',
      timeout: '${json['timeout'] ?? '0'}',
      port: '${json['port'] ?? '6379'}',
    );
  }
}

/// Redis 持久化配置（对齐 Mono-Dash RedisPersistenceDto）。
class RedisPersistenceDto {
  final String aofEnabled;
  final String rdbEnabled;
  final String save;
  final String appendfsync;

  const RedisPersistenceDto({
    this.aofEnabled = 'no',
    this.rdbEnabled = 'yes',
    this.save = '',
    this.appendfsync = 'everysec',
  });

  factory RedisPersistenceDto.fromJson(Map<String, dynamic> json) {
    return RedisPersistenceDto(
      aofEnabled:
          '${json['appendonly'] ?? json['aof_enabled'] ?? json['aofEnabled'] ?? 'no'}',
      rdbEnabled: '${json['rdb_enabled'] ?? json['rdbEnabled'] ?? 'yes'}',
      save: '${json['save'] ?? ''}',
      appendfsync: '${json['appendfsync'] ?? 'everysec'}',
    );
  }
}
