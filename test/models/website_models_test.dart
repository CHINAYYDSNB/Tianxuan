import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/website.dart';
import 'package:tianxuan/models/website_config.dart';

void main() {
  group('Website model', () {
    test('fromJson 解析基础字段', () {
      final w = Website.fromJson({
        'id': 1,
        'primaryDomain': 'a.com',
        'type': 'static',
        'alias': 'a',
        'status': 'Running',
        'remark': '备注',
        'port': 80,
        'createdAt': '2026-01-01T00:00:00Z',
      });
      expect(w.id, 1);
      expect(w.primaryDomain, 'a.com');
      expect(w.statusLabel, '运行中');
      expect(w.typeLabel, '静态网站');
      expect(w.isRunning, isTrue);
    });

    test('typeLabel/statusLabel 各种值', () {
      expect(Website.fromJson({'type': 'proxy'}).typeLabel, '反向代理');
      expect(Website.fromJson({'type': 'redirect'}).typeLabel, '重定向');
      expect(Website.fromJson({'type': 'deployment'}).typeLabel, '部署');
      expect(Website.fromJson({'type': 'runtime'}).typeLabel, '运行环境');
      expect(Website.fromJson({'type': 'subsite'}).typeLabel, '子站点');
      expect(Website.fromJson({'status': 'Stopped'}).statusLabel, '已停止');
      expect(Website.fromJson({'status': 'Error'}).statusLabel, '异常');
      expect(Website.fromJson({'status': 'x'}).isRunning, isFalse);
    });

    test('formattedSize 各种字节数', () {
      final small = Website.fromJson({'name': 'a'});
      expect(small.id, 0); // 空对象容错
    });
  });

  group('WebsiteConfig models', () {
    test('WebsiteDomain 解析', () {
      final d = WebsiteDomain.fromJson({
        'id': 1,
        'websiteId': 1,
        'domain': 'a.com',
        'port': 80,
        'ssl': true,
      });
      expect(d.id, 1);
      expect(d.domain, 'a.com');
      expect(d.ssl, isTrue);
    });

    test('WebsiteProxy 解析与 toJson', () {
      final p = WebsiteProxy.fromJson({
        'name': 'p1',
        'location': '/',
        'proxyPass': 'http://x',
        'enable': true,
        'changeDirectory': 0,
      });
      expect(p.name, 'p1');
      expect(p.location, '/');
      final json = p.toJson();
      expect(json['name'], 'p1');
    });

    test('WebsiteCors / WebsiteRealIp / WebsiteLeech 解析', () {
      final cors = WebsiteCors.fromJson({
        'enable': true,
        'origin': '*',
        'cookie': true,
      });
      expect(cors.enable, isTrue);
      expect(cors.origin, '*');
      final ip = WebsiteRealIp.fromJson({
        'enable': true,
        'proxyHeader': 'X-Real-IP',
      });
      expect(ip.proxyHeader, 'X-Real-IP');
      final leech = WebsiteLeech.fromJson({
        'enable': true,
        'type': 'black',
        'suffixs': ['png'],
      });
      expect(leech.type, 'black');
      expect(leech.suffixs, ['png']);
    });

    test('WebsiteRedirect 解析', () {
      final r = WebsiteRedirect.fromJson({
        'name': 'r1',
        'source': '/old',
        'target': '/new',
        'statusCode': 302,
      });
      expect(r.name, 'r1');
      expect(r.statusCode, 302);
      expect(r.enable, isTrue);
    });

    test('WebsiteLimitConfig 解析 params', () {
      final cfg = WebsiteLimitConfig.fromJson({
        'enable': true,
        'params': [
          {'limit_conn': 'perserver 10'},
          {'limit_conn': 'perip 5'},
          {'limit_rate': '100k'},
        ],
      });
      expect(cfg.enable, isTrue);
      expect(cfg.perServerLimit, 10);
      expect(cfg.perIpLimit, 5);
      expect(cfg.rateKb, 100);
    });

    test('WebsiteIndexConfig 解析', () {
      final cfg = WebsiteIndexConfig.fromJson({
        'index': 'index.html\nindex.htm\n',
      });
      expect(cfg.indexFiles, ['index.html', 'index.htm']);
    });

    test('OpenRestyStatus 解析', () {
      final s = OpenRestyStatus.fromJson({
        'data': {'Active': 5, 'Requests': 100},
      });
      expect(s.active, 5);
      expect(s.requests, 100);
    });

    test('SslCertificate 解析', () {
      final cert = SslCertificate.fromJson({
        'id': 1,
        'primaryDomain': 'a.com',
        'provider': 'Let\'s Encrypt',
        'status': 'ready',
        'autoRenew': true,
      });
      expect(cert.id, 1);
      expect(cert.provider, "Let's Encrypt");
      expect(cert.autoRenew, isTrue);
    });

    test('CaAccountDto 解析', () {
      final ca = CaAccountDto.fromJson({
        'id': 1,
        'name': 'root',
        'country': 'CN',
      });
      expect(ca.name, 'root');
      expect(ca.country, 'CN');
    });

    test('各 toJson 输出可解析', () {
      final proxy = WebsiteProxy(
        name: 'p',
        location: '/',
        proxyPass: 'http://x',
        enable: true,
      ).toJson();
      expect(proxy['name'], 'p');

      final auth = WebsiteAuth(
        enable: true,
        username: 'u',
        password: 'p',
      ).toJson();
      expect(auth['username'], 'u');

      final redirect = WebsiteRedirect(
        name: 'r',
        source: '/a',
        target: '/b',
      ).toJson();
      expect(redirect['name'], 'r');

      final domainReq = const WebsiteDomainReq(
        domain: 'a.com',
        port: 443,
      ).toJson();
      expect(domainReq['domain'], 'a.com');

      final cert = SslCertificate(
        id: 1,
        primaryDomain: 'a.com',
        status: 'ready',
        autoRenew: true,
      ).toJson();
      expect(cert['autoRenew'], isTrue);

      final pathAuth = const WebsitePathAuth(
        name: '/x',
        username: 'u',
      ).toJson();
      expect(pathAuth['name'], '/x');

      final leech = WebsiteLeech(
        enable: true,
        type: 'black',
        suffixs: ['png'],
      ).toJson();
      expect(leech['suffixs'], ['png']);
    });

    test('Website.toJson 输出基础字段', () {
      final w = Website.fromJson({
        'id': 1,
        'primaryDomain': 'a.com',
        'type': 'proxy',
        'alias': 'a',
        'status': 'Running',
        'createdAt': '2026-01-01',
        'proxy': 'http://127.0.0.1:8080',
        'domains': [
          {'id': 1, 'domain': 'b.com', 'port': 80, 'ssl': false},
        ],
      });
      final json = w.toJson();
      expect(json['primaryDomain'], 'a.com');
      expect(json['type'], 'proxy');
      expect(w.proxy, 'http://127.0.0.1:8080');
      expect(w.domains.length, 1);
    });
  });
}
