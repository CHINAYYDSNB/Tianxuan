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

  const mysqlInst = DatabaseInstance(
    id: '1',
    type: DbType.mysql,
    name: 'mysql',
    address: 'localhost',
    port: 3306,
    username: 'root',
    source: 'api',
  );

  group('DatabaseApi', () {
    test('listInstances 解析实例', () async {
      stub['/api/v2/databases/db/list/mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster'] =
          {
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
      expect(list[0].password, 'secret');
      expect(list[0].fromApi, isTrue);
      expect(list[1].type, DbType.redis);
      expect(list[1].port, 6379);
    });

    test('listInstances 忽略未知类型', () async {
      stub['/api/v2/databases/db/list/mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster'] =
          {
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
            {'name': 'appdb', 'format': 'utf8mb4'},
          ],
        },
      };
      final items = await DatabaseApi.searchDatabases(mysqlInst);
      expect(items.length, 1);
      expect(items.first.name, 'appdb');
    });

    test('pg 走 pg/search', () async {
      stub['/api/v2/databases/pg/search'] = {
        'code': 200,
        'data': {'items': []},
      };
      const pgInst = DatabaseInstance(
        id: '2',
        type: DbType.postgresql,
        name: 'pg',
        source: 'api',
      );
      final items = await DatabaseApi.searchDatabases(pgInst);
      expect(items, isEmpty);
    });

    test('getStatus 解析', () async {
      stub['/api/v2/databases/status'] = {
        'code': 200,
        'data': {'Status': 'running', 'Version': '8.0'},
      };
      final status = await DatabaseApi.getStatus(mysqlInst);
      expect(status['Status'], 'running');
    });

    test('createDatabase 请求正确', () async {
      stub['/api/v2/databases'] = {'code': 200, 'data': null};
      await DatabaseApi.createDatabase(mysqlInst, 'newdb');
    });

    test('deleteDatabase 成功', () async {
      stub['/api/v2/databases/del'] = {'code': 200, 'data': null};
      await DatabaseApi.deleteDatabase(mysqlInst, 'olddb');
    });

    test('changePassword 成功', () async {
      stub['/api/v2/databases/change/password'] = {'code': 200, 'data': null};
      await DatabaseApi.changePassword(mysqlInst, newPassword: 'newpass');
    });

    test('checkRemoteConnection 成功', () async {
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': true};
      final ok = await DatabaseApi.checkRemoteConnection({
        'type': 'mysql',
        'name': 'mysql',
      });
      expect(ok, isTrue);
    });

    test('checkRemoteConnection 失败', () async {
      stub['/api/v2/databases/db/check'] = {'code': 200, 'data': false};
      final ok = await DatabaseApi.checkRemoteConnection({
        'type': 'mysql',
        'name': 'mysql',
      });
      expect(ok, isFalse);
    });

    test('非 200 抛异常', () async {
      stub['/api/v2/databases/search'] = {'code': 500, 'message': 'bad'};
      expect(DatabaseApi.searchDatabases(mysqlInst), throwsA(isA<Exception>()));
    });
  });
}
