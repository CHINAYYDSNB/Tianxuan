import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/docker_api.dart';

/// 启动本地 mock server，按 path 返回 stub JSON。
Future<HttpServer> _startServer(
  Map<String, Object?> stub,
  List<String> seen,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    seen.add(req.uri.path);
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
  late List<String> seen;

  setUp(() async {
    stub = {};
    seen = [];
    server = await _startServer(stub, seen);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('DockerApi 容器', () {
    test('listContainers 解析 items', () async {
      stub['/api/v2/containers/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'containerID': 'abc123',
              'name': 'nginx',
              'imageName': 'nginx:latest',
              'state': 'running',
              'isFromCompose': true,
            },
            {'containerID': 'def456', 'name': 'redis', 'state': 'exited'},
          ],
          'total': 2,
        },
      };
      final list = await DockerApi.listContainers();
      expect(list.length, 2);
      expect(list[0].name, 'nginx');
      expect(list[0].isFromCompose, isTrue);
      expect(list[1].state, 'exited');
      expect(seen, contains('/api/v2/containers/search'));
    });

    test('operateContainer 发送 names/operation', () async {
      stub['/api/v2/containers/operate'] = {'code': 200, 'data': null};
      await DockerApi.operateContainer('nginx', 'restart');
      expect(seen, contains('/api/v2/containers/operate'));
    });

    test('containerStats 解析 stats', () async {
      stub['/api/v2/containers/stats/abc123'] = {
        'code': 200,
        'data': {'cpuPercent': 12.5, 'memory': 0.5},
      };
      final s = await DockerApi.containerStats('abc123');
      expect(s.cpuPercent, 12.5);
      expect(s.memory, 0.5);
    });

    test('containerStats code!=200 抛异常', () async {
      stub['/api/v2/containers/stats/abc123'] = {'code': 500, 'message': 'x'};
      expect(
        () => DockerApi.containerStats('abc123'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DockerApi 镜像', () {
    test('listImages 解析 tags/size', () async {
      stub['/api/v2/containers/image/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': '1',
              'tags': ['nginx:latest'],
              'size': 1024,
            },
          ],
          'total': 1,
        },
      };
      final list = await DockerApi.listImages();
      expect(list.length, 1);
      expect(list[0].tags, ['nginx:latest']);
      expect(list[0].size, 1024);
    });

    test('pullImages 发送 imageName', () async {
      stub['/api/v2/containers/image/pull'] = {'code': 200, 'data': null};
      await DockerApi.pullImages(['nginx:latest']);
      expect(seen, contains('/api/v2/containers/image/pull'));
    });

    test('removeImages 发送 ids', () async {
      stub['/api/v2/containers/image/remove'] = {'code': 200, 'data': null};
      await DockerApi.removeImages(['1', '2']);
      expect(seen, contains('/api/v2/containers/image/remove'));
    });

    test('pullImages code!=200 抛异常', () async {
      stub['/api/v2/containers/image/pull'] = {'code': 403, 'message': 'no'};
      expect(() => DockerApi.pullImages(['x']), throwsA(isA<Exception>()));
    });
  });

  group('DockerApi Compose', () {
    test('listComposes 解析 ComposeInfo', () async {
      stub['/api/v2/containers/compose/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'name': 'myapp',
              'workdir': '/opt/myapp',
              'path': '/opt/myapp/docker-compose.yml',
              'configFile': 'docker-compose.yml',
              'containerCount': 2,
              'runningCount': 2,
              'containers': [
                {'name': 'web', 'state': 'running'},
              ],
            },
          ],
          'total': 1,
        },
      };
      final list = await DockerApi.listComposes();
      expect(list.length, 1);
      expect(list[0].name, 'myapp');
      expect(list[0].workdir, '/opt/myapp');
      expect(list[0].containerCount, 2);
      expect(list[0].containers.length, 1);
    });

    test('operateCompose 发送 name/operation', () async {
      stub['/api/v2/containers/compose/operate'] = {'code': 200, 'data': null};
      await DockerApi.operateCompose('myapp', operation: 'up');
      expect(seen, contains('/api/v2/containers/compose/operate'));
    });
  });

  test('API code!=200 抛异常（供 provider fallback SSH）', () async {
    stub['/api/v2/containers/search'] = {'code': 500, 'message': 'boom'};
    expect(() => DockerApi.listContainers(), throwsA(isA<Exception>()));
  });
}
