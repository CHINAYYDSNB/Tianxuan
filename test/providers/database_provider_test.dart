import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/providers/database_provider.dart';
import 'package:tianxuan/services/database_service.dart';

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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  test('add/update/remove 维护实例列表', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(databaseInstancesProvider.notifier);

    const inst = DatabaseInstance(
      id: '1',
      type: DbType.mysql,
      name: 'db1',
      password: 'secret',
    );
    await notifier.add(inst);
    expect(container.read(databaseInstancesProvider).length, 1);

    await notifier.update(inst.copyWith(version: '8.0'));
    expect(container.read(databaseInstancesProvider).first.version, '8.0');

    await notifier.remove('1');
    expect(container.read(databaseInstancesProvider), isEmpty);
  });

  test('importFromApi 导入新实例', () async {
    stub['/api/v2/databases/db/list/mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster'] =
        {
          'code': 200,
          'data': [
            {'id': 1, 'type': 'mysql', 'database': 'mysql', 'password': 'p1'},
            {'id': 2, 'type': 'redis', 'database': 'redis'},
          ],
        };
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(databaseInstancesProvider.notifier);

    final n = await notifier.importFromApi();
    expect(n, 2);
    final list = container.read(databaseInstancesProvider);
    expect(list.length, 2);
    expect(list[0].name, 'mysql');
    expect(list[0].fromApi, isTrue);
  });

  test('importFromApi 去重', () async {
    stub['/api/v2/databases/db/list/mysql,mariadb,mysql-cluster,postgresql,postgresql-cluster,redis,redis-cluster'] =
        {
          'code': 200,
          'data': [
            {'id': 1, 'type': 'mysql', 'database': 'mysql'},
          ],
        };
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(databaseInstancesProvider.notifier);

    await notifier.importFromApi();
    final n2 = await notifier.importFromApi();
    expect(n2, 0);
    expect(container.read(databaseInstancesProvider).length, 1);
  });

  test('importFromApi 空列表返回 0', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(databaseInstancesProvider.notifier);
    final n = await notifier.importFromApi();
    expect(n, 0);
    expect(container.read(databaseInstancesProvider), isEmpty);
  });

  test('importRemote 同步远程实例', () async {
    stub['/api/v2/databases/db/search'] = {
      'code': 200,
      'data': {
        'items': [
          {'id': 5, 'name': 'rmysql', 'address': '10.0.0.1'},
        ],
      },
    };
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(databaseInstancesProvider.notifier);
    final n = await notifier.importRemote();
    expect(n, 1);
    final list = container.read(databaseInstancesProvider);
    expect(list.first.name, 'rmysql');
    expect(list.first.isRemote, isTrue);
  });

  test('databaseServiceProvider 返回 Fallback 服务', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final svc = container.read(databaseServiceProvider);
    expect(svc, isA<FallbackDatabaseService>());
  });

  group('实例 family providers', () {
    const inst = DatabaseInstance(
      id: '1',
      type: DbType.mysql,
      name: 'mysql',
      source: 'api',
      from: 'local',
    );

    test('databaseItemsProvider 解析列表', () async {
      stub['/api/v2/databases/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'appdb', 'format': 'utf8mb4'},
          ],
        },
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(databaseInstancesProvider.notifier).add(inst);
      final items = await container.read(databaseItemsProvider('1').future);
      expect(items.first.name, 'appdb');
    });

    test('databaseItemsProvider 未知实例返回空', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final items = await container.read(databaseItemsProvider('nope').future);
      expect(items, isEmpty);
    });

    test('databaseStatusProvider 解析状态', () async {
      stub['/api/v2/databases/status'] = {
        'code': 200,
        'data': {'Status': 'running'},
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(databaseInstancesProvider.notifier).add(inst);
      final status = await container.read(databaseStatusProvider('1').future);
      expect(status['Status'], 'running');
    });

    test('databaseConfigFileProvider 读取配置', () async {
      stub['/api/v2/databases/common/load/file'] = {
        'code': 200,
        'data': '[mysqld]',
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(databaseInstancesProvider.notifier).add(inst);
      final file = await container.read(databaseConfigFileProvider('1').future);
      expect(file, '[mysqld]');
    });

    test('Redis family providers', () async {
      stub['/api/v2/databases/redis/status'] = {
        'code': 200,
        'data': {'redis_version': '7.2'},
      };
      stub['/api/v2/databases/redis/conf'] = {
        'code': 200,
        'data': {'maxclients': '5000'},
      };
      stub['/api/v2/databases/redis/persistence/conf'] = {
        'code': 200,
        'data': {'appendonly': 'yes'},
      };
      const redis = DatabaseInstance(
        id: 'r',
        type: DbType.redis,
        name: 'redis',
        source: 'api',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(databaseInstancesProvider.notifier).add(redis);
      final status = await container.read(redisStatusProvider('r').future);
      expect(status['redis_version'], '7.2');
      final conf = await container.read(redisConfProvider('r').future);
      expect(conf.maxclients, '5000');
      final pers = await container.read(redisPersistenceProvider('r').future);
      expect(pers.aofEnabled, 'yes');
    });
  });
}
