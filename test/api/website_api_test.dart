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

    test('getOptions 返回选项', () async {
      stub['/api/v2/websites/options'] = {
        'code': 200,
        'data': [
          {'id': 1, 'name': 'a'},
        ],
      };
      final list = await WebsiteApi.getOptions();
      expect(list.length, 1);
    });

    test('listDomains 解析域名', () async {
      stub['/api/v2/websites/domains/5'] = {
        'code': 200,
        'data': [
          {'id': 1, 'domain': 'a.com', 'websiteId': 5},
        ],
      };
      final list = await WebsiteApi.listDomains(5);
      expect(list.length, 1);
    });

    test('getDir 返回目录配置', () async {
      stub['/api/v2/websites/dir'] = {
        'code': 200,
        'data': {'siteDir': '/opt/www'},
      };
      final d = await WebsiteApi.getDir(1);
      expect(d['siteDir'], '/opt/www');
    });

    test('updateSiteDir 发送请求', () async {
      stub['/api/v2/websites/dir/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateSiteDir(1, '/opt/x');
    });

    test('deleteDomain 发送请求', () async {
      stub['/api/v2/websites/domains/del'] = {'code': 200, 'data': null};
      await WebsiteApi.deleteDomain(3);
    });

    test('updateDomainSsl 发送请求', () async {
      stub['/api/v2/websites/domains/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateDomainSsl(3, true);
    });

    test('operate 发送请求', () async {
      stub['/api/v2/websites/operate'] = {'code': 200, 'data': null};
      await WebsiteApi.operate(1, 'start');
    });

    test('getIndexConfig 解析 index 配置', () async {
      stub['/api/v2/websites/config'] = {
        'code': 200,
        'data': {'index': 'index.html\nindex.php'},
      };
      final cfg = await WebsiteApi.getIndexConfig(1);
      expect(cfg.indexFiles, contains('index.html'));
    });

    test('getLimitConfig 解析限流配置', () async {
      stub['/api/v2/websites/config'] = {
        'code': 200,
        'data': {
          'enable': true,
          'params': [
            {'limit_conn': 'perserver 10'},
            {'limit_conn': 'perip 5'},
            {'limit_rate': '2048k'},
          ],
        },
      };
      final cfg = await WebsiteApi.getLimitConfig(1);
      expect(cfg.enable, isTrue);
      expect(cfg.perServerLimit, 10);
      expect(cfg.perIpLimit, 5);
      expect(cfg.rateKb, 2048);
    });

    test('getDir 空 data 返回空 map', () async {
      stub['/api/v2/websites/dir'] = {'code': 200, 'data': null};
      final d = await WebsiteApi.getDir(1);
      expect(d, isEmpty);
    });

    test('listPathAuths 解析路径认证', () async {
      stub['/api/v2/websites/auths/path'] = {
        'code': 200,
        'data': [
          {'name': '/admin', 'username': 'a', 'password': 'b'},
        ],
      };
      final list = await WebsiteApi.listPathAuths(1);
      expect(list.length, 1);
      expect(list[0].name, '/admin');
    });

    test('getCustomRewriteTemplates 解析模板', () async {
      stub['/api/v2/websites/rewrite/custom'] = {
        'code': 200,
        'data': ['template1', 'template2'],
      };
      final list = await WebsiteApi.getCustomRewriteTemplates();
      expect(list.length, 2);
    });

    test('getRedirects 解析重定向', () async {
      stub['/api/v2/websites/redirect'] = {
        'code': 200,
        'data': [
          {'name': 'r', 'source': '/old', 'target': '/new'},
        ],
      };
      final list = await WebsiteApi.getRedirects(1);
      expect(list.length, 1);
      expect(list[0].source, '/old');
    });

    test('getHttps 解析 HTTPS 配置', () async {
      stub['/api/v2/websites/3/https'] = {
        'code': 200,
        'data': {'enable': true},
      };
      final d = await WebsiteApi.getHttps(3);
      expect(d['enable'], isTrue);
    });

    test('getPhpRuntimes 解析运行环境', () async {
      stub['/api/v2/runtimes/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'php-8.2'},
          ],
        },
      };
      final list = await WebsiteApi.getPhpRuntimes();
      expect(list.length, 1);
    });

    test('updateAuth 发送请求', () async {
      stub['/api/v2/websites/auths/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateAuth({'enable': true});
    });

    test('updateRedirect 发送请求', () async {
      stub['/api/v2/websites/redirect/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateRedirect({'name': 'r'});
    });

    test('searchSsl 解析证书分页', () async {
      stub['/api/v2/websites/ssl/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': 1,
              'primaryDomain': 'a.com',
              'type': 'apply',
              'provider': 'letsencrypt',
              'status': 'success',
            },
          ],
          'total': 1,
        },
      };
      final r = await WebsiteApi.searchSsl(page: 1, pageSize: 50);
      expect(r['total'], 1);
      expect((r['items'] as List).length, 1);
    });

    test('deleteSsl 发送请求', () async {
      stub['/api/v2/websites/ssl/del'] = {'code': 200, 'data': null};
      await WebsiteApi.deleteSsl([1, 2]);
    });

    test('obtainSsl 发送请求', () async {
      stub['/api/v2/websites/ssl/obtain'] = {'code': 200, 'data': null};
      await WebsiteApi.obtainSsl(1);
    });

    test('updateLeech 发送请求', () async {
      stub['/api/v2/websites/leech/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateLeech({'enable': true});
    });

    test('updateCors 发送请求', () async {
      stub['/api/v2/websites/cors/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateCors({'enable': true});
    });

    test('updateRealIp 发送请求', () async {
      stub['/api/v2/websites/realip/config'] = {'code': 200, 'data': null};
      await WebsiteApi.updateRealIp({'enable': true});
    });

    test('updateIndexConfig 发送请求', () async {
      stub['/api/v2/websites/config/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateIndexConfig(1, ['index.html']);
    });

    test('updateLimitConfig 发送请求', () async {
      stub['/api/v2/websites/config/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateLimitConfig(
        1,
        enable: true,
        perServerLimit: 10,
        perIpLimit: 5,
        rateKb: 2048,
      );
    });

    test('manageCustomRewrite 发送请求', () async {
      stub['/api/v2/websites/rewrite/custom'] = {'code': 200, 'data': null};
      await WebsiteApi.manageCustomRewrite(name: 'r', operate: 'create');
    });

    test('saveRedirectFile 发送请求', () async {
      stub['/api/v2/websites/redirect/file'] = {'code': 200, 'data': null};
      await WebsiteApi.saveRedirectFile(1, 'r', 'content');
    });

    test('updateHttps 发送请求', () async {
      stub['/api/v2/websites/3/https'] = {'code': 200, 'data': null};
      await WebsiteApi.updateHttps(3, {'enable': true});
    });

    test('createSsl 发送请求', () async {
      stub['/api/v2/websites/ssl'] = {'code': 200, 'data': null};
      await WebsiteApi.createSsl({'name': 'cert'});
    });

    test('updateSsl 发送请求', () async {
      stub['/api/v2/websites/ssl/update'] = {'code': 200, 'data': null};
      await WebsiteApi.updateSsl({'id': 1});
    });

    test('getPhpRuntimes 无 items 返回空', () async {
      stub['/api/v2/runtimes/search'] = {'code': 200, 'data': {}};
      final list = await WebsiteApi.getPhpRuntimes();
      expect(list, isEmpty);
    });

    test('resolveSsl 解析 DNS 记录', () async {
      stub['/api/v2/websites/ssl/resolve'] = {
        'code': 200,
        'data': [
          {'name': '_acme-challenge', 'value': 'xxx'},
        ],
      };
      final list = await WebsiteApi.resolveSsl(1, 2);
      expect(list.length, 1);
    });
  });
}
