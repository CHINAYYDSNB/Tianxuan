import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/website_config.dart';

void main() {
  group('WebsiteProxy', () {
    test('fromJson 解析', () {
      final p = WebsiteProxy.fromJson({
        'name': 'p1',
        'type': 'location',
        'location': '/api',
        'proxyPass': 'http://127.0.0.1:8080',
        'enable': true,
        'changeDirectory': 1,
        'extraParams': [
          {'k': 'v'},
        ],
      });
      expect(p.name, 'p1');
      expect(p.proxyPass, 'http://127.0.0.1:8080');
      expect(p.extraParams.length, 1);
      expect(p.toJson()['location'], '/api');
    });
  });

  group('WebsiteAuth', () {
    test('fromJson 解析含 paths', () {
      final a = WebsiteAuth.fromJson({
        'enable': true,
        'username': 'u',
        'password': 'p',
        'paths': [
          {'name': '/admin', 'username': 'a', 'password': 'b'},
        ],
      });
      expect(a.enable, isTrue);
      expect(a.paths.length, 1);
      expect(a.paths[0].name, '/admin');
      expect(a.toJson()['username'], 'u');
    });
  });

  group('WebsiteCors / WebsiteRealIp', () {
    test('fromJson 解析', () {
      final c = WebsiteCors.fromJson({
        'enable': true,
        'origin': '*',
        'method': 'GET',
        'cookie': true,
      });
      expect(c.enable, isTrue);
      expect(c.origin, '*');
      final r = WebsiteRealIp.fromJson({
        'enable': true,
        'proxyHeader': 'X-Forwarded-For',
        'proxyIps': '1.2.3.4',
      });
      expect(r.proxyHeader, 'X-Forwarded-For');
    });
  });

  group('WebsiteLeech', () {
    test('fromJson 解析 suffixs', () {
      final l = WebsiteLeech.fromJson({
        'enable': true,
        'type': 'all',
        'servers': 'a.com',
        'suffixs': ['jpg', 'png'],
      });
      expect(l.suffixs, ['jpg', 'png']);
      expect(l.toJson()['type'], 'all');
    });
  });

  group('WebsiteRedirect', () {
    test('fromJson 默认 statusCode 301', () {
      final r = WebsiteRedirect.fromJson({
        'name': 'r',
        'source': '/old',
        'target': '/new',
      });
      expect(r.statusCode, 301);
      expect(r.source, '/old');
      final r2 = WebsiteRedirect.fromJson({'statusCode': 302});
      expect(r2.statusCode, 302);
    });
  });

  group('WebsiteIndexConfig', () {
    test('fromJson 解析多行 index', () {
      final c = WebsiteIndexConfig.fromJson({'index': 'index.html\nindex.php'});
      expect(c.indexFiles, ['index.html', 'index.php']);
    });

    test('fromJson 空 index', () {
      final c = WebsiteIndexConfig.fromJson({'index': ''});
      expect(c.indexFiles, isEmpty);
    });
  });

  group('WebsiteLimitConfig', () {
    test('fromJson 解析 params', () {
      final c = WebsiteLimitConfig.fromJson({
        'enable': true,
        'params': [
          {'limit_conn': 'perserver 10'},
          {'limit_conn': 'perip 5'},
          {'limit_rate': '2048k'},
        ],
      });
      expect(c.enable, isTrue);
      expect(c.perServerLimit, 10);
      expect(c.perIpLimit, 5);
      expect(c.rateKb, 2048);
    });
  });

  group('WebsiteDomain', () {
    test('fromJson 解析', () {
      final d = WebsiteDomain.fromJson({
        'id': 3,
        'websiteId': 1,
        'domain': 'a.com',
        'port': 443,
        'ssl': true,
      });
      expect(d.id, 3);
      expect(d.domain, 'a.com');
      expect(d.ssl, isTrue);
    });
  });

  group('SslCertificate', () {
    test('fromJson 解析 + toJson 往返', () {
      final c = SslCertificate.fromJson({
        'id': 1,
        'primaryDomain': 'a.com',
        'type': 'apply',
        'provider': 'letsencrypt',
        'status': 'success',
        'autoRenew': true,
      });
      expect(c.primaryDomain, 'a.com');
      expect(c.autoRenew, isTrue);
      expect(c.toJson()['type'], 'apply');
    });
  });

  group('AcmeAccountDto / DnsAccountDto / CaAccountDto', () {
    test('fromJson 解析', () {
      final a = AcmeAccountDto.fromJson({
        'id': 1,
        'email': 'a@b.com',
        'type': 'google',
      });
      expect(a.email, 'a@b.com');
      final d = DnsAccountDto.fromJson({
        'id': 2,
        'name': 'dns1',
        'type': 'aliyun',
      });
      expect(d.name, 'dns1');
      final c = CaAccountDto.fromJson({
        'id': 3,
        'name': 'ca1',
        'country': 'CN',
      });
      expect(c.country, 'CN');
    });
  });
}
