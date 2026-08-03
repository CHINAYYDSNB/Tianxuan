import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/website_api.dart';
import 'package:tianxuan/models/website_config.dart';

/// 启动本地 mock server，按路径返回 stub 响应。
Future<HttpServer> _startServer(
  Map<String, Object?> stub,
  List<String> seen,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    seen.add('${req.method} ${req.uri.path}');
    await req.drain();
    final v = stub[req.uri.path];
    final body = v is Map
        ? jsonEncode(v)
        : jsonEncode({'code': 200, 'data': v ?? <String, dynamic>{}});
    req.response.headers.contentType = ContentType.json;
    req.response.write(body);
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
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'key');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('WebsiteApi 基础', () {
    test('search 解析分页结果', () async {
      stub['/api/v2/websites/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': 1,
              'primaryDomain': 'a.com',
              'type': 'static',
              'alias': 'a',
              'status': 'Running',
              'createdAt': '2026-01-01',
            },
          ],
          'total': 1,
        },
      };
      final res = await WebsiteApi.search();
      expect(res['total'], 1);
      final items = res['items'] as List;
      expect(items.length, 1);
      expect(items.first.primaryDomain, 'a.com');
      expect(seen, contains('POST /api/v2/websites/search'));
    });

    test('getDetail 解析详情', () async {
      stub['/api/v2/websites/1'] = {
        'code': 200,
        'data': {
          'id': 1,
          'primaryDomain': 'a.com',
          'type': 'proxy',
          'alias': 'a',
          'status': 'Running',
          'createdAt': '2026-01-01',
        },
      };
      final w = await WebsiteApi.getDetail(1);
      expect(w.primaryDomain, 'a.com');
      expect(w.type, 'proxy');
    });

    test('operate / delete 调用对应端点', () async {
      stub['/api/v2/websites/operate'] = {'code': 200};
      stub['/api/v2/websites/del'] = {'code': 200};
      await WebsiteApi.operate(1, 'stop');
      await WebsiteApi.delete(1);
      expect(seen, contains('POST /api/v2/websites/operate'));
      expect(seen, contains('POST /api/v2/websites/del'));
    });
  });

  group('WebsiteApi 配置', () {
    test('getConfig 解析 content', () async {
      stub['/api/v2/websites/config'] = {
        'code': 200,
        'data': {'content': 'server { ... }'},
      };
      final c = await WebsiteApi.getConfig(1);
      expect(c, contains('server'));
    });

    test('getHttps 解析', () async {
      stub['/api/v2/websites/1/https'] = {
        'code': 200,
        'data': {'enable': true},
      };
      final h = await WebsiteApi.getHttps(1);
      expect(h['enable'], true);
    });

    test('listDomains 解析', () async {
      stub['/api/v2/websites/domains/1'] = {
        'code': 200,
        'data': [
          {'id': 1, 'domain': 'a.com', 'port': 80, 'ssl': false},
        ],
      };
      final domains = await WebsiteApi.listDomains(1);
      expect(domains.length, 1);
      expect(domains.first.domain, 'a.com');
    });

    test('listProxies 解析', () async {
      stub['/api/v2/websites/proxies'] = {
        'code': 200,
        'data': [
          {
            'name': 'p1',
            'location': '/',
            'proxyPass': 'http://x',
            'enable': true,
          },
        ],
      };
      final proxies = await WebsiteApi.listProxies(1);
      expect(proxies.length, 1);
      expect(proxies.first.name, 'p1');
    });

    test('getLimitConfig 解析', () async {
      stub['/api/v2/websites/config'] = {
        'code': 200,
        'data': {
          'enable': true,
          'params': [
            {'limit_conn': 'perserver 10'},
            {'limit_conn': 'perip 5'},
            {'limit_rate': '100k'},
          ],
        },
      };
      final cfg = await WebsiteApi.getLimitConfig(1);
      expect(cfg.enable, isTrue);
      expect(cfg.perServerLimit, 10);
      expect(cfg.perIpLimit, 5);
      expect(cfg.rateKb, 100);
    });
  });

  group('WebsiteApi SSL', () {
    test('searchSsl 解析', () async {
      stub['/api/v2/websites/ssl/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': 1,
              'primaryDomain': 'a.com',
              'status': 'ready',
              'expireDate': '2027-01-01',
            },
          ],
          'total': 1,
        },
      };
      final res = await WebsiteApi.searchSsl();
      final items = res['items'] as List;
      expect(items.length, 1);
      expect(items.first.primaryDomain, 'a.com');
    });

    test('searchAcmeAccounts 解析', () async {
      stub['/api/v2/websites/acme/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'email': 'a@b.com'},
          ],
          'total': 1,
        },
      };
      final accts = await WebsiteApi.searchAcmeAccounts();
      expect(accts.length, 1);
      expect(accts.first.email, 'a@b.com');
    });
  });

  group('WebsiteApi 写操作端点', () {
    test('域名增删改调用对应端点', () async {
      stub['/api/v2/websites/domains'] = {'code': 200};
      stub['/api/v2/websites/domains/update'] = {'code': 200};
      stub['/api/v2/websites/domains/del'] = {'code': 200};
      await WebsiteApi.addDomains(1, const [
        WebsiteDomainReq(domain: 'b.com', port: 80),
      ]);
      await WebsiteApi.updateDomainSsl(1, true);
      await WebsiteApi.deleteDomain(1);
      expect(seen, contains('POST /api/v2/websites/domains'));
      expect(seen, contains('POST /api/v2/websites/domains/update'));
      expect(seen, contains('POST /api/v2/websites/domains/del'));
    });

    test('目录/索引/限制端点', () async {
      stub['/api/v2/websites/dir'] = {
        'code': 200,
        'data': {'path': '/var/www'},
      };
      stub['/api/v2/websites/dir/update'] = {'code': 200};
      stub['/api/v2/websites/dir/permission'] = {'code': 200};
      stub['/api/v2/websites/config/update'] = {'code': 200};
      await WebsiteApi.getDir(1);
      await WebsiteApi.updateSiteDir(1, '/var/www');
      await WebsiteApi.updateDirPermission(1, user: 'root', group: 'root');
      await WebsiteApi.updateIndexConfig(1, ['index.html']);
      await WebsiteApi.updateLimitConfig(
        1,
        enable: true,
        perServerLimit: 5,
        perIpLimit: 2,
        rateKb: 50,
      );
      expect(seen, contains('POST /api/v2/websites/dir/update'));
      expect(seen, contains('POST /api/v2/websites/dir/permission'));
    });

    test('代理操作端点', () async {
      stub['/api/v2/websites/proxies/update'] = {'code': 200};
      stub['/api/v2/websites/proxies/delete'] = {'code': 200};
      stub['/api/v2/websites/proxies/status'] = {'code': 200};
      stub['/api/v2/websites/proxies/file'] = {'code': 200};
      await WebsiteApi.updateProxy({'name': 'p'});
      await WebsiteApi.deleteProxy(1, 'p');
      await WebsiteApi.updateProxyStatus(1, 'p', 'enable');
      await WebsiteApi.updateProxyFile(1, 'p', 'content');
      expect(seen, contains('POST /api/v2/websites/proxies/update'));
      expect(seen, contains('POST /api/v2/websites/proxies/delete'));
      expect(seen, contains('POST /api/v2/websites/proxies/status'));
    });

    test('auth/CORS/realIp/leech 端点', () async {
      stub['/api/v2/websites/auths'] = {
        'code': 200,
        'data': {'enable': true},
      };
      stub['/api/v2/websites/auths/update'] = {'code': 200};
      stub['/api/v2/websites/auths/path'] = {'code': 200, 'data': []};
      stub['/api/v2/websites/auths/path/update'] = {'code': 200};
      stub['/api/v2/websites/cors/1'] = {
        'code': 200,
        'data': {'enable': false},
      };
      stub['/api/v2/websites/cors/update'] = {'code': 200};
      stub['/api/v2/websites/realip/config/1'] = {
        'code': 200,
        'data': {'enable': true},
      };
      stub['/api/v2/websites/realip/config'] = {'code': 200};
      stub['/api/v2/websites/leech'] = {
        'code': 200,
        'data': {'enable': false},
      };
      stub['/api/v2/websites/leech/update'] = {'code': 200};
      final auth = await WebsiteApi.getAuth(1);
      expect(auth.enable, isTrue);
      final cors = await WebsiteApi.getCors(1);
      expect(cors.enable, isFalse);
      final realIp = await WebsiteApi.getRealIp(1);
      expect(realIp.enable, isTrue);
      await WebsiteApi.updateAuth({'enable': true});
      await WebsiteApi.updatePathAuth({'operate': 'add'});
      await WebsiteApi.updateCors({'enable': true});
      await WebsiteApi.updateRealIp({'enable': true});
      await WebsiteApi.updateLeech({'enable': true});
      expect(seen, contains('POST /api/v2/websites/auths/update'));
      expect(seen, contains('POST /api/v2/websites/cors/update'));
      expect(seen, contains('POST /api/v2/websites/realip/config'));
    });

    test('rewrite/redirect/PHP/资源/OpenResty/log 端点', () async {
      stub['/api/v2/websites/rewrite'] = {
        'code': 200,
        'data': {'content': 'location / {}'},
      };
      stub['/api/v2/websites/rewrite/custom'] = {
        'code': 200,
        'data': ['wordpress'],
      };
      stub['/api/v2/websites/rewrite/update'] = {'code': 200};
      stub['/api/v2/websites/redirect'] = {'code': 200, 'data': []};
      stub['/api/v2/websites/redirect/update'] = {'code': 200};
      stub['/api/v2/websites/php/version'] = {'code': 200};
      stub['/api/v2/websites/resource/1'] = {'code': 200, 'data': []};
      stub['/api/v2/websites/databases'] = {'code': 200};
      stub['/api/v2/openresty/status'] = {
        'code': 200,
        'data': {'Active': 1},
      };
      stub['/api/v2/openresty'] = {
        'code': 200,
        'data': {'content': 'worker_processes 1;'},
      };
      stub['/api/v2/websites/log'] = {
        'code': 200,
        'data': {'content': 'log'},
      };
      stub['/api/v2/websites/log/operate'] = {'code': 200};
      final rc = await WebsiteApi.getRewriteContent(1, 'w');
      expect(rc, contains('location'));
      final rewrites = await WebsiteApi.getCustomRewriteTemplates();
      expect(rewrites, ['wordpress']);
      await WebsiteApi.updateRewrite(1, 'w', 'content');
      await WebsiteApi.updateRedirect({'name': 'r'});
      await WebsiteApi.switchPhpVersion(1, 2);
      await WebsiteApi.getResources(1);
      await WebsiteApi.getDatabases();
      await WebsiteApi.changeDatabase({'websiteID': 1});
      final status = await WebsiteApi.getOpenRestyStatus();
      expect(status.active, 1);
      final cfg = await WebsiteApi.getOpenRestyConfig();
      expect(cfg, contains('worker_processes'));
      await WebsiteApi.getLog(1, 'access');
      await WebsiteApi.operateLog(1, 'access', 'clear');
      expect(seen, contains('POST /api/v2/websites/rewrite/update'));
      expect(seen, contains('POST /api/v2/websites/php/version'));
      expect(seen, contains('GET /api/v2/openresty/status'));
    });

    test('SSL 写操作端点', () async {
      stub['/api/v2/websites/ssl'] = {'code': 200};
      stub['/api/v2/websites/ssl/update'] = {'code': 200};
      stub['/api/v2/websites/ssl/del'] = {'code': 200};
      stub['/api/v2/websites/ssl/obtain'] = {'code': 200};
      stub['/api/v2/websites/ssl/upload'] = {'code': 200};
      stub['/api/v2/websites/acme'] = {'code': 200};
      stub['/api/v2/websites/acme/del'] = {'code': 200};
      stub['/api/v2/websites/dns/search'] = {
        'code': 200,
        'data': {'items': []},
      };
      stub['/api/v2/websites/dns'] = {'code': 200};
      stub['/api/v2/websites/ca/search'] = {
        'code': 200,
        'data': {'items': []},
      };
      stub['/api/v2/websites/ca'] = {'code': 200};
      await WebsiteApi.createSsl({'primaryDomain': 'a.com'});
      await WebsiteApi.updateSsl({'id': 1});
      await WebsiteApi.deleteSsl([1]);
      await WebsiteApi.obtainSsl(1);
      await WebsiteApi.uploadSsl({'type': 'paste'});
      await WebsiteApi.createAcmeAccount({'email': 'a@b.com'});
      await WebsiteApi.deleteAcmeAccount(1);
      await WebsiteApi.searchDnsAccounts();
      await WebsiteApi.createDnsAccount({'name': 'd'});
      await WebsiteApi.searchCaAccounts();
      await WebsiteApi.createCa({'name': 'ca'});
      expect(seen, contains('POST /api/v2/websites/ssl'));
      expect(seen, contains('POST /api/v2/websites/ssl/obtain'));
      expect(seen, contains('POST /api/v2/websites/acme'));
      expect(seen, contains('POST /api/v2/websites/dns'));
      expect(seen, contains('POST /api/v2/websites/ca'));
    });
  });
}
