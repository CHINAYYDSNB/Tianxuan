import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/services/database_service.dart';
import 'package:tianxuan/services/ssh_database_service.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class _MockSsh extends Mock implements SshCommandService {}

void main() {
  late _MockSsh ssh;

  setUp(() => ssh = _MockSsh());

  const mysqlInst = DatabaseInstance(
    id: '1',
    type: DbType.mysql,
    name: 'mysql',
    username: 'root',
    password: 'secret',
    source: 'manual',
  );

  const dockerInst = DatabaseInstance(
    id: '2',
    type: DbType.mysql,
    name: 'db',
    username: 'root',
    password: 'secret',
    containerName: 'mysql-container',
    inDocker: true,
    source: 'manual',
  );

  group('SshDatabaseService.searchDatabases', () {
    test('解析并过滤系统库', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout:
              'information_schema\nappdb\nmysql\nperformance_schema\nblog\n',
        ),
      );
      final svc = SshDatabaseService(ssh);
      final dbs = await svc.searchDatabases(mysqlInst);
      expect(dbs.map((e) => e.name), ['appdb', 'blog']);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('SHOW DATABASES'));
      expect(cmd, contains('MYSQL_PWD'));
    });

    test('docker 容器用 docker exec', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'db1\n'));
      final svc = SshDatabaseService(ssh);
      await svc.searchDatabases(dockerInst);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('docker exec mysql-container'));
    });

    test('远程地址加 -h -P', () async {
      const remote = DatabaseInstance(
        id: '3',
        type: DbType.mysql,
        name: 'r',
        address: '192.168.1.50',
        port: 3307,
        username: 'root',
        source: 'manual',
      );
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'x\n'));
      final svc = SshDatabaseService(ssh);
      await svc.searchDatabases(remote);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('-h 192.168.1.50 -P 3307'));
    });

    test('分页切片', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'a\nb\nc\nd\n'),
      );
      final svc = SshDatabaseService(ssh);
      final page = await svc.searchDatabases(mysqlInst, page: 2, pageSize: 2);
      expect(page.map((e) => e.name), ['c', 'd']);
    });
  });

  group('SshDatabaseService.operations', () {
    test('createDatabase 生成 CREATE DATABASE', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.createDatabase(mysqlInst, 'newdb');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CREATE DATABASE `newdb`'));
    });

    test('createDatabase 带字符集', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.createDatabase(
        mysqlInst,
        'newdb',
        format: 'utf8mb4',
        collation: 'utf8mb4_unicode_ci',
      );
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CHARACTER SET utf8mb4'));
      expect(cmd, contains('COLLATE utf8mb4_unicode_ci'));
    });

    test('deleteDatabase 生成 DROP DATABASE', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.deleteDatabase(mysqlInst, const DatabaseItem(name: 'olddb'));
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('DROP DATABASE `olddb`'));
    });

    test('changePassword 生成 ALTER USER', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.changePassword(mysqlInst, 'newpass');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains("ALTER USER 'root'@'%' IDENTIFIED BY 'newpass'"));
    });

    test('操作失败抛异常', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 1, stderr: 'Access denied'),
      );
      final svc = SshDatabaseService(ssh);
      expect(svc.createDatabase(mysqlInst, 'x'), throwsA(isA<Exception>()));
    });

    test('checkInstalled 探测容器', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'mysql-1\n'),
      );
      final svc = SshDatabaseService(ssh);
      final check = await svc.checkInstalled(mysqlInst);
      expect(check.isExist, isTrue);
      expect(check.name, 'mysql-1');
      expect(check.status, 'Running');
    });

    test('checkInstalled 未安装', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: ''));
      final svc = SshDatabaseService(ssh);
      final check = await svc.checkInstalled(mysqlInst);
      expect(check.isExist, isFalse);
      expect(check.status, 'NotExist');
    });

    test('changeAccess 生成 UPDATE mysql.user', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.changeAccess(mysqlInst, '%');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains("host='%'"));
      expect(cmd, contains('FLUSH PRIVILEGES'));
    });

    test('getRemoteAccess 识别 %', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: '%\nlocalhost\n'),
      );
      final svc = SshDatabaseService(ssh);
      expect(await svc.getRemoteAccess(mysqlInst), isTrue);
    });

    test('getRemoteAccess 未开启', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'localhost\n'),
      );
      final svc = SshDatabaseService(ssh);
      expect(await svc.getRemoteAccess(mysqlInst), isFalse);
    });

    test('updateRemoteAccess 映射到 changeAccess', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.updateRemoteAccess(mysqlInst, true);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains("host='%'"));
    });

    test('loadVariables 解析 SHOW VARIABLES', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout: 'max_connections 151\ninnodb_buffer_pool_size 134217728\n',
        ),
      );
      final svc = SshDatabaseService(ssh);
      final vars = await svc.loadVariables(mysqlInst);
      expect(vars.maxConnections, '151');
      expect(vars.innodbBufferPoolSize, '134217728');
    });

    test('updateVariables 生成 SET GLOBAL', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.updateVariables(mysqlInst, [
        {'key': 'max_connections', 'value': '200'},
      ]);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains("SET GLOBAL max_connections='200'"));
    });

    test('getFormatOptions pg 返回 COLLATION', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'C\naa_DK.utf8\n'),
      );
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final options = await svc.getFormatOptions(pg);
      expect(options.first.format, 'utf8');
      expect(options.first.collations, contains('C'));
    });

    test('getFormatOptions mysql 返回空', () async {
      final svc = SshDatabaseService(ssh);
      expect(await svc.getFormatOptions(mysqlInst), isEmpty);
    });

    test('loadConfigFile SSH 模式抛异常', () async {
      final svc = SshDatabaseService(ssh);
      expect(() => svc.loadConfigFile(mysqlInst), throwsA(isA<Exception>()));
      expect(
        () => svc.updateConfigFile(mysqlInst, 'x'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('SshDatabaseService.testConnection', () {
    test('PONG 成功', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'PONG'));
      const redis = DatabaseInstance(
        id: '4',
        type: DbType.redis,
        name: 'r',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      expect(await svc.testConnection(redis), isNull);
    });

    test('失败返回错误', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 1, stderr: 'timeout'),
      );
      final svc = SshDatabaseService(ssh);
      final err = await svc.testConnection(mysqlInst);
      expect(err, contains('timeout'));
    });
  });

  group('SshDatabaseService 多类型分支', () {
    test('pg searchDatabases 过滤系统库', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout: 'appdb\npostgres\ntemplate0\ntemplate1\npg_catalog\nblog\n',
        ),
      );
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        username: 'postgres',
        password: 'p',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final dbs = await svc.searchDatabases(pg);
      expect(dbs.map((e) => e.name), ['appdb', 'blog']);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('command -v psql'));
      expect(cmd, contains('find /usr/lib/postgresql -name psql'));
      expect(cmd, contains('docker exec'));
      expect(cmd, contains('PGPASSWORD'));
      expect(cmd, contains('POSTGRES_USER'));
    });

    test('redis searchDatabases 解析数量', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'databases\n16\n'),
      );
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final dbs = await svc.searchDatabases(redis);
      expect(dbs.length, 16);
      expect(dbs.first.name, 'db0');
    });

    test('mongo searchDatabases', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: 'admin\napp\n'),
      );
      const mongo = DatabaseInstance(
        id: 'm',
        type: DbType.mongodb,
        name: 'mongo',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final dbs = await svc.searchDatabases(mongo);
      expect(dbs.map((e) => e.name), ['admin', 'app']);
    });

    test('getStatus 执行 VERSION', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 0, stdout: '8.0.36\n'),
      );
      final svc = SshDatabaseService(ssh);
      final status = await svc.getStatus(mysqlInst);
      expect(status['raw'], contains('8.0'));
    });

    test('createDatabase pg/mongo', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        username: 'postgres',
        source: 'manual',
      );
      const mongo = DatabaseInstance(
        id: 'm',
        type: DbType.mongodb,
        name: 'mongo',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      await svc.createDatabase(pg, 'newdb');
      var cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.last
              as String;
      expect(cmd, contains('CREATE DATABASE "newdb"'));
      await svc.createDatabase(mongo, 'mydb');
      cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.last
              as String;
      expect(cmd, contains('getSiblingDB'));
    });

    test('changePassword redis', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      await svc.changePassword(redis, 'newpass');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CONFIG SET requirepass'));
    });

    test('getRedisStatus 解析 INFO', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout: '# Server\nredis_version:7.2\nconnected_clients:1\n',
        ),
      );
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final status = await svc.getRedisStatus(redis);
      expect(status['redis_version'], '7.2');
      expect(status['connected_clients'], '1');
    });

    test('updateRedisConf 生成 CONFIG SET', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      await svc.updateRedisConf(
        redis,
        timeout: '0',
        maxclients: '5000',
        maxmemory: '1048576',
      );
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CONFIG SET timeout "0" maxclients "5000"'));
    });

    test('changeRedisPassword Base64 解码后设置', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      await svc.changeRedisPassword(redis, 'c2VjcmV0');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CONFIG SET requirepass "secret"'));
    });

    test('updateRedisAofPersistence / updateRedisRdbPersistence', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      await svc.updateRedisAofPersistence(
        redis,
        appendonly: 'yes',
        appendfsync: 'always',
      );
      var cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.last
              as String;
      expect(cmd, contains('appendonly "yes" appendfsync "always"'));
      await svc.updateRedisRdbPersistence(redis, save: '3600 1');
      cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.last
              as String;
      expect(cmd, contains('CONFIG SET save "3600 1"'));
    });

    test('非 MySQL changeAccess 抛异常', () async {
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      expect(svc.changeAccess(redis, '%'), throwsA(isA<Exception>()));
    });

    test('Mongo 修改密码抛异常', () async {
      const mongo = DatabaseInstance(
        id: 'm',
        type: DbType.mongodb,
        name: 'mongo',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      expect(svc.changePassword(mongo, 'x'), throwsA(isA<Exception>()));
    });

    test('redis 不支持创建/删除数据库', () async {
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      expect(svc.createDatabase(redis, 'x'), throwsA(isA<Exception>()));
      expect(
        svc.deleteDatabase(redis, const DatabaseItem(name: 'x')),
        throwsA(isA<Exception>()),
      );
    });

    test('getRedisConf 解析 CONFIG GET', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout:
              'maxclients\n10000\nmaxmemory\n0\ntimeout\n0\n'
              'requirepass\n\n',
        ),
      );
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final conf = await svc.getRedisConf(redis);
      expect(conf.maxclients, '10000');
      expect(conf.maxmemory, '0');
    });

    test('getRedisPersistence 解析', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout: 'appendonly\nyes\nsave\n3600 1\nappendfsync\neverysec\n',
        ),
      );
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      final pers = await svc.getRedisPersistence(redis);
      expect(pers.aofEnabled, 'yes');
      expect(pers.save, '3600 1');
      expect(pers.appendfsync, 'everysec');
    });

    test('listInstances 探测 Docker 容器', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout: 'mysql-1 mysql:8.0\nredis-1 redis:7\nother nginx\n',
        ),
      );
      final svc = SshDatabaseService(ssh);
      final list = await svc.listInstances();
      expect(list.map((e) => e.name), ['mysql-1', 'redis-1']);
      expect(list.first.type, DbType.mysql);
    });

    test('listInstances 无容器返回空', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(exitCode: 1, stderr: 'docker not found'),
      );
      final svc = SshDatabaseService(ssh);
      expect(await svc.listInstances(), isEmpty);
    });

    test('deleteDatabase 用 instanceName', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.deleteDatabase(
        mysqlInst,
        const DatabaseItem(name: 'r1', mysqlName: 'appdb', pgName: 'pgdb'),
      );
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('DROP DATABASE `pgdb`'));
    });
  });

  group('FallbackDatabaseService', () {
    test('手动实例无 SSH 抛异常', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(svc.searchDatabases(mysqlInst), throwsA(isA<Exception>()));
    });

    test('手动实例走 SSH', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'db1\n'));
      final svc = FallbackDatabaseService(ssh: SshDatabaseService(ssh));
      final dbs = await svc.searchDatabases(mysqlInst);
      expect(dbs.map((e) => e.name), ['db1']);
    });

    test('api 实例 API 失败 fallback SSH', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'db1\n'));
      const apiInst = DatabaseInstance(
        id: 'a',
        type: DbType.mysql,
        name: 'mysql',
        source: 'api',
      );
      final svc = FallbackDatabaseService(ssh: SshDatabaseService(ssh));
      final dbs = await svc.searchDatabases(apiInst);
      expect(dbs.map((e) => e.name), ['db1']);
    });

    test('无 SSH 时 testConnection 返回提示', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(await svc.testConnection(mysqlInst), contains('无可用的连接方式'));
    });

    test('无 SSH 时 getStatus 返回空', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(await svc.getStatus(mysqlInst), isEmpty);
    });

    test('无 SSH 时 delete/create/changePassword 抛异常', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(
        svc.deleteDatabase(mysqlInst, const DatabaseItem(name: 'x')),
        throwsA(isA<Exception>()),
      );
      expect(svc.createDatabase(mysqlInst, 'x'), throwsA(isA<Exception>()));
      expect(svc.changePassword(mysqlInst, 'x'), throwsA(isA<Exception>()));
    });

    test('无 SSH 时 Redis 配置返回默认值', () async {
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = FallbackDatabaseService(ssh: null);
      expect((await svc.getRedisConf(redis)).maxclients, '10000');
      expect((await svc.getRedisPersistence(redis)).aofEnabled, 'no');
      expect(await svc.getRedisStatus(redis), isEmpty);
    });
  });
}
