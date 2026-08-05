import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/providers/database_provider.dart';

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
}
