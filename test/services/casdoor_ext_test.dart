import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/services/casdoor_service.dart';

void main() {
  group('CasdoorProvider.fromJson', () {
    test('解析 OAuth 快捷登录 provider', () {
      final p = CasdoorProvider.fromJson({
        'name': 'GitHub',
        'rule': 'Login',
        'provider': {
          'type': 'GitHub',
          'category': 'OAuth',
          'displayName': 'GitHub',
          'clientId': 'github_client',
        },
      });
      expect(p.name, 'GitHub');
      expect(p.type, 'GitHub');
      expect(p.category, 'OAuth');
      expect(p.displayName, 'GitHub');
      expect(p.clientId, 'github_client');
      expect(p.isOAuthProvider, isTrue);
      expect(p.iconKey, 'github');
    });

    test('解析 GEETEST captcha provider', () {
      final p = CasdoorProvider.fromJson({
        'name': 'captcha',
        'rule': 'Login',
        'provider': {
          'type': 'GEETEST',
          'category': 'Captcha',
          'clientId': 'gt4_captcha_id',
        },
      });
      expect(p.isCaptchaProvider, isTrue);
      expect(p.isOAuthProvider, isFalse);
      expect(p.clientId, 'gt4_captcha_id');
    });

    test('provider 缺失时容错', () {
      final p = CasdoorProvider.fromJson({'name': 'x'});
      expect(p.type, '');
      expect(p.clientId, '');
      expect(p.isOAuthProvider, isFalse);
    });
  });

  group('CasdoorAccount.fromJson', () {
    test('解析邮箱与绑定的第三方', () {
      final a = CasdoorAccount.fromJson({
        'id': 'uuid-1',
        'name': 'alice',
        'displayName': 'Alice',
        'avatar': 'http://img/a.png',
        'email': 'a@b.com',
        'github': 'alice',
        'google': 'alice@gmail',
        'wechat': '',
      });
      expect(a.id, 'uuid-1');
      expect(a.displayName, 'Alice');
      expect(a.email, 'a@b.com');
      expect(a.hasEmail, isTrue);
      expect(a.linkedProviders, contains('github'));
      expect(a.linkedProviders, contains('google'));
      expect(a.linkedProviders, isNot(contains('wechat')));
    });

    test('无邮箱时 hasEmail 为 false', () {
      final a = CasdoorAccount.fromJson({'id': 'x', 'email': ''});
      expect(a.hasEmail, isFalse);
      expect(a.linkedProviders, isEmpty);
    });

    test('永久头像回退', () {
      final a = CasdoorAccount.fromJson({
        'avatar': '',
        'permanentAvatar': 'http://img/perm.png',
        'email': 'x@y.com',
      });
      expect(a.avatar, 'http://img/perm.png');
    });
  });

  group('CasdoorService buildProviderAuthUrl', () {
    test('包含 provider 参数', () {
      final url = CasdoorService.buildProviderAuthUrl(
        providerName: 'GitHub',
        redirectUri: 'com.tianxuan.app://callback',
        state: 's123',
      );
      final uri = Uri.parse(url);
      expect(uri.path, '/login/oauth/authorize');
      expect(uri.queryParameters['provider'], 'GitHub');
      expect(uri.queryParameters['applicationId'], 'Tianxuan/Tianxuan');
      expect(uri.queryParameters['state'], 's123');
    });

    test('buildSignupUrl 指向 /api/signup', () {
      final url = CasdoorService.buildSignupUrl(
        verifier: 'v' * 64,
        challenge: 'c',
        state: 's',
        redirectUri: 'r',
      );
      final uri = Uri.parse(url);
      expect(uri.path, '/api/signup');
      expect(uri.queryParameters['applicationId'], 'Tianxuan/Tianxuan');
    });
  });
}
