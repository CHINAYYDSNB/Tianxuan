import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/services/database_service.dart';
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

  group('SshDatabaseService.listDatabases', () {
    test('解析并过滤系统库', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (_) async => const SshResult(
          exitCode: 0,
          stdout:
              'information_schema\nappdb\nmysql\nperformance_schema\nblog\n',
        ),
      );
      final svc = SshDatabaseService(ssh);
      final dbs = await svc.listDatabases(mysqlInst);
      expect(dbs.map((e) => e.name), ['appdb', 'blog']);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('SHOW DATABASES'));
      expect(cmd, contains("MYSQL_PWD='secret'"));
    });

    test('docker 容器用 docker exec', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'db1\n'));
      final svc = SshDatabaseService(ssh);
      await svc.listDatabases(dockerInst);
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
      await svc.listDatabases(remote);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('-h 192.168.1.50 -P 3307'));
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

    test('deleteDatabase 生成 DROP DATABASE', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      final svc = SshDatabaseService(ssh);
      await svc.deleteDatabase(mysqlInst, 'olddb');
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
    test('pg listDatabases 过滤系统库', () async {
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
      final dbs = await svc.listDatabases(pg);
      expect(dbs.map((e) => e.name), ['appdb', 'blog']);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('command -v psql'));
      expect(cmd, contains('find /usr/lib/postgresql -name psql'));
      expect(cmd, contains('docker exec'));
      expect(cmd, contains("PGPASSWORD='p'"));
    });

    test('redis listDatabases 解析数量', () async {
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
      final dbs = await svc.listDatabases(redis);
      expect(dbs.length, 16);
      expect(dbs.first.name, 'db0');
    });

    test('mongo listDatabases', () async {
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
      final dbs = await svc.listDatabases(mongo);
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

    test('redis 不支持创建/删除数据库', () async {
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'manual',
      );
      final svc = SshDatabaseService(ssh);
      expect(svc.createDatabase(redis, 'x'), throwsA(isA<Exception>()));
      expect(svc.deleteDatabase(redis, 'x'), throwsA(isA<Exception>()));
    });
  });

  group('FallbackDatabaseService', () {
    test('手动实例无 SSH 抛异常', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(svc.listDatabases(mysqlInst), throwsA(isA<Exception>()));
    });

    test('手动实例走 SSH', () async {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'db1\n'));
      final svc = FallbackDatabaseService(ssh: SshDatabaseService(ssh));
      final dbs = await svc.listDatabases(mysqlInst);
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
      final dbs = await svc.listDatabases(apiInst);
      expect(dbs.map((e) => e.name), ['db1']);
    });

    test('无 SSH 时 testConnection 返回提示', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(await svc.testConnection(mysqlInst), contains('无可用连接方式'));
    });

    test('无 SSH 时 getStatus 返回空', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(await svc.getStatus(mysqlInst), isEmpty);
    });

    test('无 SSH 时 delete 抛异常', () async {
      final svc = FallbackDatabaseService(ssh: null);
      expect(svc.deleteDatabase(mysqlInst, 'x'), throwsA(isA<Exception>()));
      expect(svc.createDatabase(mysqlInst, 'x'), throwsA(isA<Exception>()));
      expect(svc.changePassword(mysqlInst, 'x'), throwsA(isA<Exception>()));
    });
  });
}
