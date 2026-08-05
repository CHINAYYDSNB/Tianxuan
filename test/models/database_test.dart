import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/database.dart';

void main() {
  group('DbTypeMeta', () {
    test('默认端口', () {
      expect(DbType.mysql.defaultPort, '3306');
      expect(DbType.postgresql.defaultPort, '5432');
      expect(DbType.redis.defaultPort, '6379');
      expect(DbType.mongodb.defaultPort, '27017');
    });

    test('默认用户', () {
      expect(DbType.mysql.defaultUser, 'root');
      expect(DbType.postgresql.defaultUser, 'postgres');
    });

    test('密码环境变量', () {
      expect(DbType.mysql.passwordEnvVars, contains('MYSQL_ROOT_PASSWORD'));
      expect(DbType.postgresql.passwordEnvVars, contains('POSTGRES_PASSWORD'));
    });
  });

  group('DbInstance', () {
    test('label 组合', () {
      final inst = DbInstance(
        type: DbType.mysql,
        inDocker: true,
        containerName: 'mysql-1',
        version: '8.0',
      );
      expect(inst.label, contains('MySQL'));
      expect(inst.label, contains('[Docker]'));
      expect(inst.label, contains('mysql-1'));
    });

    test('subtitle 组合', () {
      final inst = DbInstance(
        type: DbType.redis,
        port: 6379,
        status: 'running',
      );
      expect(inst.subtitle, contains('6379'));
      expect(inst.subtitle, contains('running'));
    });

    test('cliCmd 映射', () {
      expect(DbInstance(type: DbType.mysql).cliCmd, 'mysql');
      expect(DbInstance(type: DbType.postgresql).cliCmd, 'psql');
      expect(DbInstance(type: DbType.mongodb).cliCmd, 'mongosh');
      expect(DbInstance(type: DbType.redis).cliCmd, 'redis-cli');
    });

    test('connArgs 注入用户名', () {
      final inst = DbInstance(type: DbType.mysql, authUser: 'root');
      expect(inst.connArgs, '-uroot');
    });

    test('wrapCmd 注入密码环境变量', () {
      final inst = DbInstance(
        type: DbType.mysql,
        authUser: 'root',
        authPass: 'secret',
      );
      final wrapped = inst.wrapCmd('mysql -uroot -e "SELECT 1"');
      expect(wrapped, contains("MYSQL_PWD='secret'"));
      expect(wrapped, contains('mysql -uroot'));
    });

    test('wrapCmd docker exec', () {
      final inst = DbInstance(
        type: DbType.redis,
        inDocker: true,
        containerName: 'redis-1',
        authPass: 'p',
      );
      final wrapped = inst.wrapCmd('redis-cli PING');
      expect(wrapped, contains('docker exec redis-1'));
      expect(wrapped, contains('redis-cli PING'));
    });

    test('needsAuth', () {
      expect(DbInstance(type: DbType.mysql, authPass: 'x').needsAuth, isTrue);
      expect(DbInstance(type: DbType.redis).needsAuth, isFalse);
    });
  });
}
