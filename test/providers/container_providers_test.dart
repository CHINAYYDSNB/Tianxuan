import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/providers/container_provider.dart';
import 'package:tianxuan/providers/image_provider.dart';
import 'package:tianxuan/providers/compose_provider.dart';
import 'package:tianxuan/providers/website_provider.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late Map<String, Object?> stub;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('容器 provider', () {
    test('从 API 拉取容器列表', () async {
      stub['/api/v2/containers/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'containerID': 'a', 'name': 'nginx', 'state': 'running'},
          ],
        },
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final list = await container.read(containerListProvider.future);
      expect(list.length, 1);
      expect(list[0].name, 'nginx');
    });
  });

  group('镜像 provider', () {
    test('从 API 拉取镜像', () async {
      stub['/api/v2/containers/image/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': '1',
              'tags': ['nginx:latest'],
              'size': 100,
            },
          ],
        },
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final list = await container.read(imageListProvider.future);
      expect(list.length, 1);
      expect(list[0].tags.first, 'nginx:latest');
    });
  });

  group('Compose provider', () {
    test('从 API 拉取 compose', () async {
      stub['/api/v2/containers/compose/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'name': 'app', 'workdir': '/opt/app'},
          ],
        },
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final list = await container.read(composeListProvider.future);
      expect(list.length, 1);
      expect(list[0].name, 'app');
    });
  });

  group('website provider', () {
    test('从 API 拉取网站列表', () async {
      stub['/api/v2/websites/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'primaryDomain': 'example.com'},
          ],
          'total': 1,
        },
      };
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final list = await container.read(websitesProvider.future);
      expect(list.length, 1);
    });
  });
}
