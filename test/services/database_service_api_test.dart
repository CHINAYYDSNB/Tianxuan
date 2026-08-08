import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/services/database_service.dart';
import 'package:tianxuan/services/ssh_database_service.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class _MockSsh extends Mock implements SshCommandService {}

Future<HttpServer> _startServer(Map<String, Object?> stub) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    await req.drain();
    req.response.headers.contentType = ContentType.json;
    req.response.write(
      jsonEncode(stub[req.uri.path] ?? {'code': 200, 'data': {}}),
    );
    await req.response.close();
  });
  return s;
}

const _mysqlApi = DatabaseInstance(
  id: 'a1',
  apiId: 1,
  type: DbType.mysql,
  name: 'mysql',
  username: 'root',
  password: 'secret',
  source: 'api',
  from: 'local',
);

const _remoteApi = DatabaseInstance(
  id: 'a2',
  apiId: 5,
  type: DbType.mysql,
  name: 'rmysql',
  source: 'api',
  from: 'remote',
);

void main() {
  late HttpServer server;
  late Map<String, Object?> stub;
  late _MockSsh ssh;

  setUp(() async {
    HttpOverrides.global = null;
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
    ssh = _MockSsh();
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('ApiDatabaseService', () {
    test('listInstances', () async {
      stub['/api/v2/databases/db/list/${DbTypeMeta.apiListTypes}'] = {
        'code': 200,
        'data': [
          {'id': 1, 'type': 'mysql', 'database': 'mysql'},
        ],
      };
      final svc = ApiDatabaseService();
      final list = await svc.listInstances();
      expect(list.length, 1);
    });

    test('checkInstalled', () async {
      stub['/api/v2/apps/installed/check'] = {
        'code': 200,
        'data': {'isExist': true, 'name': 'mysql-1', 'version': '8.0'},
      };
      final svc = ApiDatabaseService();
      final check = await svc.checkInstalled(_mysqlApi);
      expect(check.isExist, isTrue);
      expect(check.name, 'mysql-1');
    });

    test('searchDatabases / getFormatOptions', () async {
      stub['/api/v2/databases/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'appdb'},
          ],
        },
      };
      stub['/api/v2/databases/format/options'] = {
        'code': 200,
        'data': [
          {
            'format': 'utf8mb4',
            'collations': ['utf8mb4_unicode_ci'],
          },
        ],
      };
      final svc = ApiDatabaseService();
      final items = await svc.searchDatabases(_mysqlApi);
      expect(items.first.name, 'appdb');
      final options = await svc.getFormatOptions(_mysqlApi);
      expect(options.first.format, 'utf8mb4');
    });

    test('createDatabase mysql/pg', () async {
      stub['/api/v2/databases'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/pg'] = {'code': 200, 'data': null};
      final svc = ApiDatabaseService();
      await svc.createDatabase(_mysqlApi, 'newdb', format: 'utf8mb4');
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        source: 'api',
      );
      await svc.createDatabase(pg, 'newpg');
    });

    test('deleteDatabase 本地未被占用', () async {
      stub['/api/v2/databases/del/check'] = {'code': 200, 'data': <Object?>[]};
      stub['/api/v2/databases/del'] = {'code': 200, 'data': null};
      final svc = ApiDatabaseService();
      await svc.deleteDatabase(
        _mysqlApi,
        const DatabaseItem(name: 'olddb', id: 3),
      );
    });

    test('deleteDatabase 本地被占用抛异常', () async {
      stub['/api/v2/databases/del/check'] = {
        'code': 200,
        'data': [
          {'type': 'website', 'name': 'blog'},
        ],
      };
      final svc = ApiDatabaseService();
      expect(
        svc.deleteDatabase(_mysqlApi, const DatabaseItem(name: 'olddb')),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteDatabase 远程走 db/del', () async {
      stub['/api/v2/databases/db/del'] = {'code': 200, 'data': null};
      final svc = ApiDatabaseService();
      await svc.deleteDatabase(
        _remoteApi,
        const DatabaseItem(name: 'rmysql', id: 5),
      );
    });

    test('changePassword / changeAccess / remote access', () async {
      stub['/api/v2/databases/change/password'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/change/access'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/remote'] = {'code': 200, 'data': true};
      final svc = ApiDatabaseService();
      await svc.changePassword(_mysqlApi, 'newpass');
      await svc.changeAccess(_mysqlApi, '%');
      expect(await svc.getRemoteAccess(_mysqlApi), isTrue);
      await svc.updateRemoteAccess(_mysqlApi, true);
    });

    test('loadFromRemote / loadPgFromRemote', () async {
      stub['/api/v2/databases/load'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/pg/pg/load'] = {'code': 200, 'data': null};
      final svc = ApiDatabaseService();
      await svc.loadFromRemote(_mysqlApi);
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        source: 'api',
      );
      await svc.loadPgFromRemote(pg);
    });

    test('getStatus / config file', () async {
      stub['/api/v2/databases/status'] = {
        'code': 200,
        'data': {'Status': 'running'},
      };
      stub['/api/v2/databases/common/load/file'] = {
        'code': 200,
        'data': '[mysqld]',
      };
      stub['/api/v2/databases/common/update/conf'] = {
        'code': 200,
        'data': null,
      };
      final svc = ApiDatabaseService();
      final status = await svc.getStatus(_mysqlApi);
      expect(status['Status'], 'running');
      expect(await svc.loadConfigFile(_mysqlApi), '[mysqld]');
      await svc.updateConfigFile(_mysqlApi, '[mysqld]');
    });

    test('variables', () async {
      stub['/api/v2/databases/variables'] = {
        'code': 200,
        'data': {'max_connections': '151'},
      };
      stub['/api/v2/databases/variables/update'] = {'code': 200, 'data': null};
      final svc = ApiDatabaseService();
      final vars = await svc.loadVariables(_mysqlApi);
      expect(vars.maxConnections, '151');
      await svc.updateVariables(_mysqlApi, [
        {'key': 'max_connections', 'value': '200'},
      ]);
    });

    test('Redis 系列 API', () async {
      stub['/api/v2/databases/redis/status'] = {
        'code': 200,
        'data': {'redis_version': '7.2'},
      };
      stub['/api/v2/databases/redis/conf'] = {
        'code': 200,
        'data': {'maxclients': '10000'},
      };
      stub['/api/v2/databases/redis/conf/update'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/redis/password'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/redis/persistence/conf'] = {
        'code': 200,
        'data': {'appendonly': 'yes'},
      };
      stub['/api/v2/databases/redis/persistence/update'] = {
        'code': 200,
        'data': null,
      };
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'api',
      );
      final svc = ApiDatabaseService();
      final status = await svc.getRedisStatus(redis);
      expect(status['redis_version'], '7.2');
      expect((await svc.getRedisConf(redis)).maxclients, '10000');
      await svc.updateRedisConf(
        redis,
        timeout: '0',
        maxclients: '10000',
        maxmemory: '0',
      );
      await svc.changeRedisPassword(redis, 'c2VjcmV0');
      expect((await svc.getRedisPersistence(redis)).aofEnabled, 'yes');
      await svc.updateRedisAofPersistence(
        redis,
        appendonly: 'yes',
        appendfsync: 'everysec',
      );
      await svc.updateRedisRdbPersistence(redis, save: '3600 1');
    });

    test('testConnection 成功/失败', () async {
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': true};
      final svc = ApiDatabaseService();
      expect(await svc.testConnection(_mysqlApi), isNull);
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': false};
      expect(await svc.testConnection(_mysqlApi), isNotNull);
    });
  });

  group('FallbackDatabaseService API 路径', () {
    late FallbackDatabaseService svc;

    setUp(() {
      svc = FallbackDatabaseService(ssh: SshDatabaseService(ssh));
    });

    test('listInstances API 成功', () async {
      stub['/api/v2/databases/db/list/${DbTypeMeta.apiListTypes}'] = {
        'code': 200,
        'data': [
          {'id': 1, 'type': 'mysql', 'database': 'mysql'},
        ],
      };
      final list = await svc.listInstances();
      expect(list.length, 1);
    });

    test('searchDatabases API 成功', () async {
      stub['/api/v2/databases/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'appdb'},
          ],
        },
      };
      final items = await svc.searchDatabases(_mysqlApi);
      expect(items.first.name, 'appdb');
    });

    test('createDatabase API 成功', () async {
      stub['/api/v2/databases'] = {'code': 200, 'data': null};
      await svc.createDatabase(_mysqlApi, 'newdb');
    });

    test('deleteDatabase API 成功', () async {
      stub['/api/v2/databases/del/check'] = {'code': 200, 'data': <Object?>[]};
      stub['/api/v2/databases/del'] = {'code': 200, 'data': null};
      await svc.deleteDatabase(
        _mysqlApi,
        const DatabaseItem(name: 'olddb', id: 3),
      );
    });

    test('changePassword / changeAccess / remote access API 成功', () async {
      stub['/api/v2/databases/change/password'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/change/access'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/remote'] = {'code': 200, 'data': true};
      await svc.changePassword(_mysqlApi, 'newpass');
      await svc.changeAccess(_mysqlApi, '%');
      expect(await svc.getRemoteAccess(_mysqlApi), isTrue);
      await svc.updateRemoteAccess(_mysqlApi, true);
    });

    test('loadFromRemote / loadPgFromRemote / getStatus API 成功', () async {
      stub['/api/v2/databases/load'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/pg/pg/load'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/status'] = {
        'code': 200,
        'data': {'Status': 'running'},
      };
      await svc.loadFromRemote(_mysqlApi);
      const pg = DatabaseInstance(
        id: 'pg',
        type: DbType.postgresql,
        name: 'pg',
        source: 'api',
      );
      await svc.loadPgFromRemote(pg);
      final status = await svc.getStatus(_mysqlApi);
      expect(status['Status'], 'running');
    });

    test('config file / variables API 成功', () async {
      stub['/api/v2/databases/common/load/file'] = {
        'code': 200,
        'data': '[mysqld]',
      };
      stub['/api/v2/databases/common/update/conf'] = {
        'code': 200,
        'data': null,
      };
      stub['/api/v2/databases/variables'] = {
        'code': 200,
        'data': {'max_connections': '151'},
      };
      stub['/api/v2/databases/variables/update'] = {'code': 200, 'data': null};
      expect(await svc.loadConfigFile(_mysqlApi), '[mysqld]');
      await svc.updateConfigFile(_mysqlApi, '[mysqld]');
      expect((await svc.loadVariables(_mysqlApi)).maxConnections, '151');
      await svc.updateVariables(_mysqlApi, [
        {'key': 'max_connections', 'value': '200'},
      ]);
    });

    test('Redis API 成功', () async {
      stub['/api/v2/databases/redis/status'] = {
        'code': 200,
        'data': {'redis_version': '7.2'},
      };
      stub['/api/v2/databases/redis/conf'] = {
        'code': 200,
        'data': {'maxclients': '10000'},
      };
      stub['/api/v2/databases/redis/conf/update'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/redis/password'] = {'code': 200, 'data': null};
      stub['/api/v2/databases/redis/persistence/conf'] = {
        'code': 200,
        'data': {'appendonly': 'yes'},
      };
      stub['/api/v2/databases/redis/persistence/update'] = {
        'code': 200,
        'data': null,
      };
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'api',
      );
      expect((await svc.getRedisStatus(redis))['redis_version'], '7.2');
      expect((await svc.getRedisConf(redis)).maxclients, '10000');
      await svc.updateRedisConf(
        redis,
        timeout: '0',
        maxclients: '10000',
        maxmemory: '0',
      );
      await svc.changeRedisPassword(redis, 'c2VjcmV0');
      expect((await svc.getRedisPersistence(redis)).aofEnabled, 'yes');
      await svc.updateRedisAofPersistence(
        redis,
        appendonly: 'yes',
        appendfsync: 'everysec',
      );
      await svc.updateRedisRdbPersistence(redis, save: '3600 1');
    });

    test('checkInstalled / testConnection API 成功', () async {
      stub['/api/v2/apps/installed/check'] = {
        'code': 200,
        'data': {'isExist': true},
      };
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': true};
      expect((await svc.checkInstalled(_mysqlApi)).isExist, isTrue);
      expect(await svc.testConnection(_mysqlApi), isNull);
    });
  });

  group('FallbackDatabaseService SSH 降级', () {
    late FallbackDatabaseService svc;

    setUp(() {
      // API 指向死端口，强制 API 失败。
      ApiClient.instance.testConfigure('http://127.0.0.1:1', 'k');
      svc = FallbackDatabaseService(ssh: SshDatabaseService(ssh));
    });

    void okSsh({String stdout = ''}) {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 0, stdout: stdout));
    }

    test('searchDatabases 降级 SSH', () async {
      okSsh(stdout: 'db1\ndb2\n');
      final items = await svc.searchDatabases(_mysqlApi);
      expect(items.map((e) => e.name), ['db1', 'db2']);
    });

    test('createDatabase 降级 SSH', () async {
      okSsh();
      await svc.createDatabase(_mysqlApi, 'newdb');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CREATE DATABASE `newdb`'));
    });

    test('deleteDatabase 降级 SSH', () async {
      okSsh();
      await svc.deleteDatabase(_mysqlApi, const DatabaseItem(name: 'olddb'));
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('DROP DATABASE `olddb`'));
    });

    test('changePassword / changeAccess / remote access 降级 SSH', () async {
      okSsh();
      await svc.changePassword(_mysqlApi, 'newpass');
      await svc.changeAccess(_mysqlApi, '%');
      await svc.updateRemoteAccess(_mysqlApi, true);
      verify(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).called(3);
    });

    test('getRemoteAccess 降级 SSH', () async {
      okSsh(stdout: '%\n');
      expect(await svc.getRemoteAccess(_mysqlApi), isTrue);
    });

    test('listUsers 降级 SSH 解析', () async {
      okSsh(stdout: 'root %\napp 192.168.1.5\n');
      final users = await svc.listUsers(_mysqlApi);
      expect(users.length, 2);
      expect(users.first.username, 'root');
      expect(users.first.host, '%');
    });

    test('bindUser 降级 SSH 构造 CREATE USER', () async {
      okSsh();
      await svc.bindUser(
        _mysqlApi,
        database: 'appdb',
        username: 'app',
        password: 'pw',
      );
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('CREATE USER'));
    });

    test('deleteUser 降级 SSH 构造 DROP USER', () async {
      okSsh();
      await svc.deleteUser(_mysqlApi, 'app');
      final cmd =
          verify(
                () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
              ).captured.first
              as String;
      expect(cmd, contains('DROP USER'));
    });

    test('getStatus 降级 SSH', () async {
      okSsh(stdout: '8.0.36\n');
      final status = await svc.getStatus(_mysqlApi);
      expect(status['raw'], contains('8.0'));
    });

    test('loadVariables 降级 SSH', () async {
      okSsh(stdout: 'max_connections 151\n');
      final vars = await svc.loadVariables(_mysqlApi);
      expect(vars.maxConnections, '151');
    });

    test('Redis conf 降级 SSH', () async {
      okSsh(
        stdout: 'maxclients\n10000\nmaxmemory\n0\ntimeout\n0\nrequirepass\n\n',
      );
      final conf = await svc.getRedisConf(_mysqlApi);
      expect(conf.maxclients, '10000');
    });

    test('listInstances 降级 SSH', () async {
      okSsh(stdout: 'mysql-1 mysql:8.0\n');
      final list = await svc.listInstances();
      expect(list.first.name, 'mysql-1');
    });
  });

  group('FallbackDatabaseService 无 SSH 抛异常', () {
    late FallbackDatabaseService svc;

    setUp(() {
      ApiClient.instance.testConfigure('http://127.0.0.1:1', 'k');
      svc = FallbackDatabaseService(ssh: null);
    });

    test('loadConfigFile 抛异常', () {
      expect(svc.loadConfigFile(_mysqlApi), throwsA(isA<Exception>()));
    });

    test('updateConfigFile 抛异常', () {
      expect(svc.updateConfigFile(_mysqlApi, 'x'), throwsA(isA<Exception>()));
    });

    test('updateVariables 抛异常', () {
      expect(
        svc.updateVariables(_mysqlApi, [
          {'key': 'a', 'value': 'b'},
        ]),
        throwsA(isA<Exception>()),
      );
    });

    test('updateRedisConf 抛异常', () {
      expect(
        svc.updateRedisConf(
          _mysqlApi,
          timeout: '0',
          maxclients: '1',
          maxmemory: '0',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('changeRedisPassword 抛异常', () {
      expect(
        svc.changeRedisPassword(_mysqlApi, 'c2VjcmV0'),
        throwsA(isA<Exception>()),
      );
    });

    test('updateRedisAofPersistence 抛异常', () {
      expect(
        svc.updateRedisAofPersistence(
          _mysqlApi,
          appendonly: 'yes',
          appendfsync: 'everysec',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateRedisRdbPersistence 抛异常', () {
      expect(
        svc.updateRedisRdbPersistence(_mysqlApi, save: '3600 1'),
        throwsA(isA<Exception>()),
      );
    });

    test('loadFromRemote / loadPgFromRemote 无异常', () async {
      // SSH 模式下为空操作，API 失败也不抛。
      await svc.loadFromRemote(_mysqlApi);
      await svc.loadPgFromRemote(_mysqlApi);
    });

    test('用户方法无 SSH 抛异常', () {
      expect(svc.listUsers(_mysqlApi), throwsA(isA<Exception>()));
      expect(
        svc.bindUser(_mysqlApi, database: 'db', username: 'u', password: 'p'),
        throwsA(isA<Exception>()),
      );
      expect(svc.deleteUser(_mysqlApi, 'u'), throwsA(isA<Exception>()));
    });
  });
}
