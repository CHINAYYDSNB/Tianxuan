import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/database.dart';

void main() {
  group('DbTypeMeta', () {
    test('fromString 识别各类型', () {
      expect(DbTypeMeta.fromString('mysql'), DbType.mysql);
      expect(DbTypeMeta.fromString('MariaDB'), DbType.mariadb);
      expect(DbTypeMeta.fromString('postgresql'), DbType.postgresql);
      expect(DbTypeMeta.fromString('mongo'), DbType.mongodb);
      expect(DbTypeMeta.fromString('redis'), DbType.redis);
      expect(DbTypeMeta.fromString(''), isNull);
    });

    test('默认端口', () {
      expect(DbType.mysql.defaultPort, 3306);
      expect(DbType.postgresql.defaultPort, 5432);
      expect(DbType.redis.defaultPort, 6379);
      expect(DbType.mongodb.defaultPort, 27017);
    });

    test('默认用户', () {
      expect(DbType.mysql.defaultUser, 'root');
      expect(DbType.postgresql.defaultUser, 'postgres');
    });

    test('apiListTypes 含全部类型', () {
      expect(DbTypeMeta.apiListTypes, contains('mysql'));
      expect(DbTypeMeta.apiListTypes, contains('postgresql'));
      expect(DbTypeMeta.apiListTypes, contains('redis'));
    });

    test('isRedis / isPostgres / apiType / label', () {
      expect(DbType.redis.isRedis, isTrue);
      expect(DbType.mysql.isRedis, isFalse);
      expect(DbType.postgresql.isPostgres, isTrue);
      expect(DbType.mariadb.apiType, 'mariadb');
      expect(DbType.mongodb.label, 'MongoDB');
    });
  });

  group('DatabaseInstance', () {
    test('toJson/fromJson 往返', () {
      const inst = DatabaseInstance(
        id: '1',
        type: DbType.mysql,
        name: 'test',
        address: 'localhost',
        port: 3306,
        username: 'root',
        version: '8.0',
        source: 'api',
      );
      final restored = DatabaseInstance.fromJson(inst.toJson());
      expect(restored.id, '1');
      expect(restored.type, DbType.mysql);
      expect(restored.name, 'test');
      expect(restored.address, 'localhost');
      expect(restored.port, 3306);
      expect(restored.username, 'root');
      expect(restored.source, 'api');
      expect(restored.fromApi, isTrue);
    });

    test('默认值', () {
      final inst = DatabaseInstance.fromJson({
        'id': 'x',
        'type': 'redis',
        'name': 'r',
      });
      expect(inst.port, 6379);
      expect(inst.address, 'localhost');
      expect(inst.source, 'manual');
      expect(inst.fromApi, isFalse);
    });

    test('copyWith 保留字段', () {
      const inst = DatabaseInstance(id: '1', type: DbType.mysql, name: 'n');
      final updated = inst.copyWith(password: 'p', version: '9.0');
      expect(updated.password, 'p');
      expect(updated.version, '9.0');
      expect(updated.name, 'n');
    });

    test('apiId / from 序列化往返', () {
      const inst = DatabaseInstance(
        id: 'r1',
        apiId: 7,
        type: DbType.postgresql,
        name: 'pg',
        from: 'remote',
        address: '10.0.0.2',
        port: 5432,
        username: 'postgres',
      );
      final restored = DatabaseInstance.fromJson(inst.toJson());
      expect(restored.apiId, 7);
      expect(restored.from, 'remote');
      expect(restored.isRemote, isTrue);
      expect(restored.displayAddress, '10.0.0.2:5432');
    });

    test('Docker 实例展示容器名', () {
      const inst = DatabaseInstance(
        id: 'd',
        type: DbType.mysql,
        name: 'db',
        containerName: 'mysql-c',
        inDocker: true,
      );
      expect(inst.displayAddress, 'Docker: mysql-c');
    });

    test('copyWith 更新 apiId/from/地址', () {
      const inst = DatabaseInstance(id: '1', type: DbType.mysql, name: 'n');
      final updated = inst.copyWith(apiId: 9, from: 'remote', port: 3307);
      expect(updated.apiId, 9);
      expect(updated.from, 'remote');
      expect(updated.port, 3307);
    });
  });

  group('DatabaseItem', () {
    test('fromJson 解析', () {
      final item = DatabaseItem.fromJson({
        'name': 'mydb',
        'format': 'utf8mb4',
        'collation': 'utf8mb4_unicode_ci',
        'username': 'root',
        'permission': 'ALL',
      });
      expect(item.name, 'mydb');
      expect(item.format, 'utf8mb4');
      expect(item.collation, 'utf8mb4_unicode_ci');
      expect(item.username, 'root');
    });

    test('mysqlName 回退', () {
      final item = DatabaseItem.fromJson({'mysqlName': 'db1'});
      expect(item.name, 'db1');
    });

    test('完整字段解析（对齐 DatabaseSearchItemDto）', () {
      final item = DatabaseItem.fromJson({
        'id': 5,
        'createdAt': '2026-01-01',
        'name': 'r1',
        'from': 'remote',
        'mysqlName': 'appdb',
        'format': 'utf8mb4',
        'collation': 'utf8mb4_unicode_ci',
        'username': 'app',
        'password': 'p',
        'permission': 'ALL',
        'isDelete': true,
        'description': 'desc',
        'postgresqlName': 'pgdb',
        'superUser': true,
      });
      expect(item.id, 5);
      expect(item.createdAt, '2026-01-01');
      expect(item.from, 'remote');
      expect(item.mysqlName, 'appdb');
      expect(item.password, 'p');
      expect(item.isDelete, isTrue);
      expect(item.description, 'desc');
      expect(item.pgName, 'pgdb');
      expect(item.superUser, isTrue);
      expect(item.instanceName, 'pgdb');
    });

    test('instanceName 优先 pgName', () {
      const item = DatabaseItem(name: 'r1', mysqlName: 'appdb', pgName: 'pgdb');
      expect(item.instanceName, 'pgdb');
      const plain = DatabaseItem(name: 'r1');
      expect(plain.instanceName, '');
    });
  });

  group('DatabaseCheckDto', () {
    test('fromJson 解析', () {
      final dto = DatabaseCheckDto.fromJson({
        'isExist': true,
        'name': 'mysql-1',
        'app': 'mysql',
        'version': '8.0',
        'status': 'Running',
        'createdAt': '2026-01-01',
        'lastBackupAt': '',
        'appInstallId': 3,
        'containerName': 'mysql-1',
        'installPath': '/opt/1panel',
        'httpPort': 3306,
        'httpsPort': 0,
        'websiteDir': '/www',
      });
      expect(dto.isExist, isTrue);
      expect(dto.name, 'mysql-1');
      expect(dto.version, '8.0');
      expect(dto.appInstallId, 3);
      expect(dto.httpPort, 3306);
    });

    test('默认值', () {
      expect(const DatabaseCheckDto().isExist, isFalse);
      expect(DatabaseCheckDto.fromJson({}).isExist, isFalse);
    });
  });

  group('DBResourceDto / FormatCollationOption', () {
    test('DBResourceDto 解析', () {
      final dto = DBResourceDto.fromJson({'type': 'website', 'name': 'blog'});
      expect(dto.type, 'website');
      expect(dto.name, 'blog');
    });

    test('FormatCollationOption 解析', () {
      final opt = FormatCollationOption.fromJson({
        'format': 'utf8mb4',
        'collations': ['utf8mb4_unicode_ci', 'utf8mb4_general_ci'],
      });
      expect(opt.format, 'utf8mb4');
      expect(opt.collations.length, 2);
      expect(const FormatCollationOption(format: '').collations, isEmpty);
    });
  });

  group('MysqlVariables', () {
    test('fromJson 映射下划线字段', () {
      final vars = MysqlVariables.fromJson({
        'max_connections': '151',
        'innodb_buffer_pool_size': '134217728',
        'slow_query_log': 'ON',
        'thread_stack': '262144',
      });
      expect(vars.maxConnections, '151');
      expect(vars.innodbBufferPoolSize, '134217728');
      expect(vars.slowQueryLog, 'ON');
      expect(vars.threadStackSize, '262144');
    });

    test('toMap 输出下划线字段', () {
      const vars = MysqlVariables(maxConnections: '200', longQueryTime: '2');
      final map = vars.toMap();
      expect(map['max_connections'], '200');
      expect(map['long_query_time'], '2');
      expect(map.containsKey('tmp_table_size'), isFalse);
    });
  });

  group('RedisConfDto / RedisPersistenceDto', () {
    test('RedisConfDto 解析', () {
      final conf = RedisConfDto.fromJson({
        'maxclients': '5000',
        'maxmemory': '1048576',
        'requirepass': 'x',
        'timeout': '30',
        'port': '6380',
      });
      expect(conf.maxclients, '5000');
      expect(conf.maxmemory, '1048576');
      expect(conf.port, '6380');
      expect(const RedisConfDto().maxclients, '10000');
    });

    test('RedisPersistenceDto 兼容 appendonly 键', () {
      final pers = RedisPersistenceDto.fromJson({
        'appendonly': 'yes',
        'save': '3600 1',
        'appendfsync': 'always',
      });
      expect(pers.aofEnabled, 'yes');
      expect(pers.save, '3600 1');
      expect(pers.appendfsync, 'always');
    });

    test('RedisPersistenceDto 兼容 aof_enabled / 默认值', () {
      final pers = RedisPersistenceDto.fromJson({
        'aof_enabled': 'no',
        'rdb_enabled': 'yes',
      });
      expect(pers.aofEnabled, 'no');
      expect(pers.rdbEnabled, 'yes');
      expect(const RedisPersistenceDto().aofEnabled, 'no');
      expect(const RedisPersistenceDto().rdbEnabled, 'yes');
    });
  });
}
