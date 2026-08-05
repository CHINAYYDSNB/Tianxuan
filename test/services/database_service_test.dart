import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/services/database_service.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class _MockSsh extends Mock implements SshCommandService {}

void main() {
  late _MockSsh ssh;
  late DatabaseService svc;

  setUp(() {
    ssh = _MockSsh();
    svc = DatabaseService(ssh);
  });

  void stubOk(String? stdout, {String stderr = ''}) {
    when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
      (_) async => SshResult(
        exitCode: stderr.isEmpty ? 0 : 1,
        stdout: stdout ?? '',
        stderr: stderr,
      ),
    );
  }

  DbInstance mysqlInst({String? pass}) => DbInstance(
    type: DbType.mysql,
    authUser: 'root',
    authPass: pass ?? 'secret',
  );

  group('detectAll', () {
    test('原生 + Docker 检测', () async {
      when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer(
        (inv) async {
          final cmd = inv.positionalArguments.first as String;
          if (cmd.contains('docker ps')) {
            return const SshResult(
              exitCode: 0,
              stdout: 'abc123\tmysql-1\tmysql:8.0\t0.0.0.0:3306->3306/tcp\n',
            );
          }
          if (cmd.contains('--version')) {
            return const SshResult(
              exitCode: 0,
              stdout: 'mysql  Ver 8.0.36\nFOUND',
            );
          }
          return const SshResult(exitCode: 0, stdout: '');
        },
      );
      final all = await svc.detectAll();
      expect(all, isNotEmpty);
      final docker = all.where((e) => e.inDocker).toList();
      expect(docker, isNotEmpty);
      expect(docker.first.containerName, 'mysql-1');
    });
  });

  group('listDatabases', () {
    test('mysql 过滤系统库', () async {
      stubOk(
        'appdb\ninformation_schema\nmysql\nperformance_schema\nblog\nsys\n',
      );
      final dbs = await svc.listDatabases(mysqlInst());
      expect(dbs.map((e) => e.name), ['appdb', 'blog']);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('SHOW DATABASES'));
    });

    test('redis 解析数量', () async {
      stubOk('__REDIS__\ndatabases\n16\n');
      final dbs = await svc.listDatabases(
        DbInstance(type: DbType.redis, authPass: 'p'),
      );
      expect(dbs.length, 16);
      expect(dbs.first.name, 'db0');
    });
  });

  group('operations', () {
    test('createDatabase', () async {
      stubOk('');
      final err = await svc.createDatabase(mysqlInst(), 'newdb');
      expect(err, isEmpty);
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CREATE DATABASE'));
    });

    test('deleteDatabase', () async {
      stubOk('');
      final err = await svc.deleteDatabase(mysqlInst(), 'olddb');
      expect(err, isEmpty);
    });

    test('操作失败返回错误', () async {
      stubOk('', stderr: 'Access denied');
      final err = await svc.createDatabase(mysqlInst(), 'x');
      expect(err, contains('Access denied'));
    });
  });

  group('users', () {
    test('listUsers mysql 解析', () async {
      stubOk('root\t%\napp\nroot\tlocalhost\n');
      final users = await svc.listUsers(mysqlInst());
      expect(users, isNotEmpty);
      expect(users.first.name, 'root');
      expect(users.first.host, '%');
    });

    test('createUser/deleteUser/changePassword', () async {
      stubOk('');
      expect(await svc.createUser(mysqlInst(), 'alice', 'pass'), isEmpty);
      expect(await svc.deleteUser(mysqlInst(), 'alice'), isEmpty);
      expect(
        await svc.changePassword(mysqlInst(), 'alice', 'newpass'),
        isEmpty,
      );
    });

    test('grantPrivileges', () async {
      stubOk('');
      expect(await svc.grantPrivileges(mysqlInst(), 'alice', 'appdb'), isEmpty);
    });
  });

  group('credentials & connection', () {
    test('testCredentials 成功', () async {
      stubOk('1');
      expect(await svc.testCredentials(mysqlInst()), isNull);
    });

    test('testCredentials 失败返回错误', () async {
      stubOk('', stderr: 'failed');
      expect(await svc.testCredentials(mysqlInst()), isNotNull);
    });

    test('tryDetectCredentials docker env', () async {
      stubOk('POSTGRES_PASSWORD=secret\nPOSTGRES_USER=pguser\n');
      final inst = DbInstance(
        type: DbType.postgresql,
        inDocker: true,
        containerName: 'pg-1',
      );
      final creds = await svc.tryDetectCredentials(inst);
      expect(creds, isNotNull);
      expect(creds!.user, 'pguser');
      expect(creds.pass, 'secret');
    });

    test('getConnectionInfo 宿主机', () async {
      stubOk('8.0.36\n');
      final info = await svc.getConnectionInfo(mysqlInst());
      expect(info, contains('8.0'));
    });
  });
}
