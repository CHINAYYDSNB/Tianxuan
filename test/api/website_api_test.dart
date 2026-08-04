import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/website_api.dart';
import 'package:tianxuan/models/website.dart';

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

  group('WebsiteApi', () {
    test('getList 解析网站列表', () async {
      stub['/api/v2/websites/list'] = {
        'code': 200,
        'data': [
          {
            'id': 1,
            'primaryDomain': 'a.com',
            'type': 'proxy',
            'alias': 'a',
            'status': 'running',
            'createdAt': '2026',
          },
          {
            'id': 2,
            'primaryDomain': 'b.com',
            'type': 'proxy',
            'alias': 'b',
            'status': 'running',
            'createdAt': '2026',
          },
        ],
      };
      final list = await WebsiteApi.getList();
      expect(list.length, 2);
      expect(list[0].primaryDomain, 'a.com');
    });

    test('search 解析分页结果', () async {
      stub['/api/v2/websites/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': 1,
              'primaryDomain': 'a.com',
              'type': 'proxy',
              'alias': 'a',
              'status': 'running',
              'createdAt': '2026',
            },
          ],
          'total': 1,
        },
      };
      final r = await WebsiteApi.search(page: 1, pageSize: 20);
      expect(r['total'], 1);
      expect((r['items'] as List).length, 1);
    });

    test('getDetail 解析详情', () async {
      stub['/api/v2/websites/5'] = {
        'code': 200,
        'data': {
          'id': 5,
          'primaryDomain': 'c.com',
          'type': 'proxy',
          'alias': 'c',
          'status': 'running',
          'createdAt': '2026',
        },
      };
      final w = await WebsiteApi.getDetail(5);
      expect(w.id, 5);
      expect(w.primaryDomain, 'c.com');
    });

    test('check 返回是否可用', () async {
      stub['/api/v2/websites/check'] = {'code': 200, 'data': true};
      expect(await WebsiteApi.check('x.com', 'proxy'), isTrue);
    });

    test('delete 发送请求', () async {
      stub['/api/v2/websites/del'] = {'code': 200, 'data': null};
      await WebsiteApi.delete(1);
    });

    test('create 调用后返回 ID', () async {
      stub['/api/v2/websites'] = {'code': 200, 'data': null};
      stub['/api/v2/websites/list'] = {
        'code': 200,
        'data': [
          {
            'id': 9,
            'primaryDomain': 'new.com',
            'type': 'proxy',
            'alias': 'new-alias',
            'status': 'running',
            'createdAt': '2026',
          },
        ],
      };
      final req = WebsiteCreateRequest(
        primaryDomain: 'new.com',
        type: 'proxy',
        alias: 'new-alias',
      );
      final id = await WebsiteApi.create(req);
      expect(id, 9);
    });
  });
}
