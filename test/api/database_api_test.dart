import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/database_api.dart';
import 'package:tianxuan/models/database.dart';

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

const _listPath =
    '/api/v2/databases/db/list/mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster';

void main() {
  late HttpServer server;
  late Map<String, Object?> stub;

  setUp(() async {
    HttpOverrides.global = null;
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('DatabaseApi', () {
    test('listInstances 解析实例', () async {
      stub[_listPath] = {
        'code': 200,
        'data': [
          {
            'id': 1,
            'type': 'mysql',
            'database': 'mysql',
            'version': '8.0',
            'address': '127.0.0.1',
            'port': 3306,
            'username': 'root',
            'password': 'secret',
          },
          {'id': 2, 'type': 'redis', 'database': 'redis', 'port': 6379},
        ],
      };
      final list = await DatabaseApi.listInstances();
      expect(list.length, 2);
      expect(list[0].name, 'mysql');
      expect(list[0].type, DbType.mysql);
      expect(list[0].apiId, 1);
      expect(list[0].password, 'secret');
      expect(list[0].fromApi, isTrue);
      expect(list[1].type, DbType.redis);
      expect(list[1].port, 6379);
    });

    test('listInstances 忽略未知类型', () async {
      stub[_listPath] = {
        'code': 200,
        'data': [
          {'id': 1, 'type': 'unknown', 'database': 'x'},
        ],
      };
      final list = await DatabaseApi.listInstances();
      expect(list, isEmpty);
    });

    test('searchDatabases 解析 items', () async {
      stub['/api/v2/databases/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'name': 'appdb', 'format': 'utf8mb4', 'id': 3},
          ],
        },
      };
      final items = await DatabaseApi.searchDatabases(
        database: 'mysql',
        type: 'mysql',
      );
      expect(items.length, 1);
      expect(items.first.name, 'appdb');
      expect(items.first.id, 3);
      expect(items.first.instanceName, 'appdb');
    });

    test('pg 走 pg/search 且解析 postgresqlName', () async {
      stub['/api/v2/databases/pg/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'r1', 'postgresqlName': 'pgdb'},
          ],
        },
      };
      final items = await DatabaseApi.searchDatabases(
        database: 'pg',
        type: 'postgresql',
      );
      expect(items.length, 1);
      expect(items.first.pgName, 'pgdb');
      expect(items.first.instanceName, 'pgdb');
    });

    test('loadPgFromRemote 成功', () async {
      stub['/api/v2/databases/pg/pg1/load'] = {'code': 200, 'data': null};
      await DatabaseApi.loadPgFromRemote(database: 'pg1');
    });

    test('getStatus 解析', () async {
      stub['/api/v2/databases/status'] = {
        'code': 200,
        'data': {'Status': 'running', 'Version': '8.0'},
      };
      final status = await DatabaseApi.getStatus(type: 'mysql', name: 'mysql');
      expect(status['Status'], 'running');
    });

    test('checkDelete 解析占用资源', () async {
      stub['/api/v2/databases/del/check'] = {
        'code': 200,
        'data': [
          {'type': 'website', 'name': 'blog'},
        ],
      };
      final occupied = await DatabaseApi.checkDelete(
        id: 1,
        type: 'mysql',
        database: 'mysql',
      );
      expect(occupied.length, 1);
      expect(occupied.first.name, 'blog');
    });

    test('deleteDatabase 成功', () async {
      stub['/api/v2/databases/del'] = {'code': 200, 'data': null};
      await DatabaseApi.deleteDatabase(id: 1, type: 'mysql', database: 'mysql');
    });

    test('changePassword 成功（value 为 Base64）', () async {
      stub['/api/v2/databases/change/password'] = {'code': 200, 'data': null};
      await DatabaseApi.changePassword(
        id: 1,
        from: 'local',
        type: 'mysql',
        database: 'mysql',
        value: DatabaseApi.encodeValue('newpass'),
      );
    });

    test('changeAccess 成功', () async {
      stub['/api/v2/databases/change/access'] = {'code': 200, 'data': null};
      await DatabaseApi.changeAccess(
        id: 0,
        from: 'local',
        type: 'mysql',
        database: 'mysql',
        value: '%',
      );
    });

    test('updateRemoteAccess 映射到 changeAccess', () async {
      stub['/api/v2/databases/change/access'] = {'code': 200, 'data': null};
      await DatabaseApi.updateRemoteAccess(
        type: 'mysql',
        database: 'mysql',
        remote: true,
      );
    });

    test('checkRemoteConnection 成功/失败', () async {
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': true};
      expect(
        await DatabaseApi.checkRemoteConnection({
          'type': 'mysql',
          'name': 'mysql',
        }),
        isTrue,
      );
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': false};
      expect(
        await DatabaseApi.checkRemoteConnection({
          'type': 'mysql',
          'name': 'mysql',
        }),
        isFalse,
      );
    });

    test('createRemoteDatabase 成功', () async {
      stub['/api/v2/databases/db'] = {'code': 200, 'data': null};
      await DatabaseApi.createRemoteDatabase({
        'name': 'remote1',
        'type': 'mysql',
        'from': 'remote',
      });
    });

    test('searchRemoteDatabases 解析远程实例', () async {
      stub['/api/v2/databases/db/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 5, 'name': 'rmysql', 'address': '10.0.0.1', 'port': 3306},
          ],
        },
      };
      final list = await DatabaseApi.searchRemoteDatabases(type: 'mysql');
      expect(list.length, 1);
      expect(list.first.name, 'rmysql');
      expect(list.first.isRemote, isTrue);
    });

    test('getDatabase 返回详情', () async {
      stub['/api/v2/databases/db/rmysql'] = {
        'code': 200,
        'data': {'address': '10.0.0.1'},
      };
      final m = await DatabaseApi.getDatabase('rmysql');
      expect(m['address'], '10.0.0.1');
    });

    test('updateRemoteDatabase / deleteRemoteDatabase 成功', () async {
      stub['/api/v2/databases/db/update'] = {'code': 200, 'data': null};
      await DatabaseApi.updateRemoteDatabase({'name': 'rmysql'});
      stub['/api/v2/databases/db/del'] = {'code': 200, 'data': null};
      await DatabaseApi.deleteRemoteDatabase(id: 5, database: 'rmysql');
    });

    test('getRemoteAccess 成功', () async {
      stub['/api/v2/databases/remote'] = {'code': 200, 'data': true};
      final ok = await DatabaseApi.getRemoteAccess(
        type: 'mysql',
        name: 'mysql',
      );
      expect(ok, isTrue);
    });

    test('getFormatOptions 解析', () async {
      stub['/api/v2/databases/format/options'] = {
        'code': 200,
        'data': [
          {
            'format': 'utf8mb4',
            'collations': ['utf8mb4_unicode_ci'],
          },
        ],
      };
      final options = await DatabaseApi.getFormatOptions('mysql');
      expect(options.length, 1);
      expect(options.first.format, 'utf8mb4');
      expect(options.first.collations, contains('utf8mb4_unicode_ci'));
    });

    test('createDatabase / createPgDatabase / loadFromRemote 成功', () async {
      stub['/api/v2/databases'] = {'code': 200, 'data': null};
      await DatabaseApi.createDatabase({'type': 'mysql', 'name': 'newdb'});
      stub['/api/v2/databases/pg'] = {'code': 200, 'data': null};
      await DatabaseApi.createPgDatabase({'type': 'postgresql', 'name': 'pg'});
      stub['/api/v2/databases/load'] = {'code': 200, 'data': null};
      await DatabaseApi.loadFromRemote(
        from: 'local',
        type: 'mysql',
        database: 'mysql',
      );
    });

    test('loadConfigFile / updateConfigFile 成功', () async {
      stub['/api/v2/databases/common/load/file'] = {
        'code': 200,
        'data': '[mysqld]',
      };
      final file = await DatabaseApi.loadConfigFile(
        type: 'mysql',
        name: 'mysql',
      );
      expect(file, '[mysqld]');
      stub['/api/v2/databases/common/update/conf'] = {
        'code': 200,
        'data': null,
      };
      await DatabaseApi.updateConfigFile(
        type: 'mysql',
        database: 'mysql',
        file: '[mysqld]',
      );
    });

    test('loadVariables / updateVariables 成功', () async {
      stub['/api/v2/databases/variables'] = {
        'code': 200,
        'data': {'max_connections': '151'},
      };
      final vars = await DatabaseApi.loadVariables(
        type: 'mysql',
        name: 'mysql',
      );
      expect(vars.maxConnections, '151');
      stub['/api/v2/databases/variables/update'] = {'code': 200, 'data': null};
      await DatabaseApi.updateVariables(
        type: 'mysql',
        database: 'mysql',
        variables: [
          {'key': 'max_connections', 'value': '200'},
        ],
      );
    });

    test('Redis 状态/配置/持久化 API', () async {
      stub['/api/v2/databases/redis/status'] = {
        'code': 200,
        'data': {'redis_version': '7.2'},
      };
      final status = await DatabaseApi.getRedisStatus(
        type: 'redis',
        name: 'redis',
      );
      expect(status['redis_version'], '7.2');

      stub['/api/v2/databases/redis/conf'] = {
        'code': 200,
        'data': {'maxclients': '10000'},
      };
      final conf = await DatabaseApi.getRedisConf(type: 'redis', name: 'redis');
      expect(conf.maxclients, '10000');

      stub['/api/v2/databases/redis/conf/update'] = {'code': 200, 'data': null};
      await DatabaseApi.updateRedisConf(
        dbType: 'redis',
        database: 'redis',
        timeout: '0',
        maxclients: '10000',
        maxmemory: '0',
      );

      stub['/api/v2/databases/redis/password'] = {'code': 200, 'data': null};
      await DatabaseApi.changeRedisPassword(
        database: 'redis',
        value: DatabaseApi.encodeValue('secret'),
      );

      stub['/api/v2/databases/redis/persistence/conf'] = {
        'code': 200,
        'data': {'appendonly': 'yes'},
      };
      final pers = await DatabaseApi.getRedisPersistence(
        type: 'redis',
        name: 'redis',
      );
      expect(pers.aofEnabled, 'yes');

      stub['/api/v2/databases/redis/persistence/update'] = {
        'code': 200,
        'data': null,
      };
      await DatabaseApi.updateRedisAofPersistence(
        dbType: 'redis',
        database: 'redis',
        appendonly: 'yes',
        appendfsync: 'everysec',
      );
      await DatabaseApi.updateRedisRdbPersistence(
        dbType: 'redis',
        database: 'redis',
        save: '3600 1',
      );
    });

    test('loadDatabaseItems 解析', () async {
      stub['/api/v2/databases/db/item/mysql'] = {
        'code': 200,
        'data': [
          {'name': 'appdb'},
        ],
      };
      final items = await DatabaseApi.loadDatabaseItems('mysql');
      expect(items.length, 1);
      expect(items.first.name, 'appdb');
    });

    test('非 200 抛异常', () async {
      stub['/api/v2/databases/search'] = {'code': 500, 'message': 'bad'};
      expect(
        DatabaseApi.searchDatabases(database: 'mysql', type: 'mysql'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
