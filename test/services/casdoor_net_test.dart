import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/services/casdoor_service.dart';
import 'package:tianxuan/services/storage_service.dart';

Future<HttpServer> _startServer(
  Map<String, Object?> stub,
  List<String> seen,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    seen.add('${req.method} ${req.uri.path}');
    req.response.headers.contentType = ContentType.json;
    final v = stub[req.uri.path];
    if (v is Map && v.containsKey('__body')) {
      // 先读请求体再回显（__body 是 String->Map 的转换函数）
      final body = await utf8.decoder.bind(req).join();
      req.response.write(jsonEncode(v['__body'](body)));
    } else {
      await req.drain();
      req.response.write(jsonEncode(v ?? {'code': 200, 'data': {}}));
    }
    await req.response.close();
  });
  return s;
}

void main() {
  late HttpServer server;
  late Map<String, Object?> stub;
  late List<String> seen;

  setUp(() async {
    // 恢复真实 HttpClient（flutter_test binding 默认拦截所有 HTTP 返回 400）
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    stub = {};
    seen = [];
    server = await _startServer(stub, seen);
    CasdoorService.baseUrl = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    CasdoorService.baseUrl = 'https://logto.lingqi.vip';
    await server.close(force: true);
  });

  group('CasdoorService.getLoginProviders', () {
    test('解析快捷登录与 GEETEST provider', () async {
      stub['/api/get-app-login'] = {
        'code': 200,
        'data': {
          'providers': [
            {
              'name': 'GitHub',
              'rule': 'Login',
              'provider': {
                'type': 'GitHub',
                'category': 'OAuth',
                'clientId': 'gh_client',
              },
            },
            {
              'name': 'captcha',
              'rule': 'Login',
              'provider': {
                'type': 'GEETEST',
                'category': 'Captcha',
                'clientId': 'gt4_id',
              },
            },
          ],
        },
      };
      final providers = await CasdoorService.getLoginProviders();
      expect(providers.length, 2);
      expect(
        providers.any((p) => p.isOAuthProvider && p.type == 'GitHub'),
        isTrue,
      );
      expect(
        providers.any((p) => p.isCaptchaProvider && p.clientId == 'gt4_id'),
        isTrue,
      );
    });

    test('非 200 返回空列表', () async {
      stub['/api/get-app-login'] = {'code': 500, 'msg': 'err'};
      final providers = await CasdoorService.getLoginProviders();
      expect(providers, isEmpty);
    });
  });

  group('CasdoorService.loginWithPassword', () {
    test('带 captchaToken 提交 /api/login', () async {
      Map<String, dynamic>? sentBody;
      stub['/api/login'] = {
        'code': 200,
        'data': null,
        'accessToken': 'at123',
        'refreshToken': 'rt123',
        'idToken': 'it123',
        '__body': (String body) {
          sentBody = jsonDecode(body) as Map<String, dynamic>;
          return {'code': 200, 'accessToken': 'at123'};
        },
      };
      final ok = await CasdoorService.loginWithPassword(
        email: 'a@b.com',
        password: 'secret',
        captchaToken: 'lot_number=L&captcha_output=C',
      );
      expect(ok, isTrue);
      expect(seen, contains('POST /api/login'));
      expect(sentBody!['type'], 'login');
      expect(sentBody!['username'], 'a@b.com');
      expect(sentBody!['captchaType'], 'GEETEST');
      expect(sentBody!['captchaToken'], 'lot_number=L&captcha_output=C');
    });

    test('登录失败返回 false', () async {
      stub['/api/login'] = {'code': 401, 'msg': 'bad'};
      final ok = await CasdoorService.loginWithPassword(
        email: 'a@b.com',
        password: 'x',
      );
      expect(ok, isFalse);
    });
  });

  group('CasdoorService.signup', () {
    test('成功返回 ok=true', () async {
      stub['/api/signup'] = {'code': 200, 'msg': 'ok'};
      final r = await CasdoorService.signup(
        email: 'a@b.com',
        username: 'alice',
        password: 'secret123',
      );
      expect(r.ok, isTrue);
      expect(seen, contains('POST /api/signup'));
    });

    test('失败返回 message', () async {
      stub['/api/signup'] = {'code': 400, 'msg': '邮箱已存在'};
      final r = await CasdoorService.signup(
        email: 'a@b.com',
        username: 'alice',
        password: 'secret123',
      );
      expect(r.ok, isFalse);
      expect(r.message, '邮箱已存在');
    });
  });

  group('CasdoorService.getAccount', () {
    test('无 token 返回 null', () async {
      expect(await CasdoorService.getAccount(), isNull);
    });

    test('解析完整账户资料', () async {
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'at',
        expiresIn: 3600,
      );
      stub['/api/get-account'] = {
        'code': 200,
        'data': {
          'id': 'u1',
          'name': 'alice',
          'displayName': 'Alice',
          'email': 'a@b.com',
          'avatar': 'http://img/a.png',
          'github': 'alice-gh',
          'google': '',
        },
      };
      final acc = await CasdoorService.getAccount();
      expect(acc, isNotNull);
      expect(acc!.email, 'a@b.com');
      expect(acc.linkedProviders, contains('github'));
      expect(acc.hasEmail, isTrue);
    });
  });

  group('CasdoorService URL 构建', () {
    test('buildProviderAuthUrl 含 provider 参数', () {
      final url = CasdoorService.buildProviderAuthUrl(
        providerName: 'GitHub',
        redirectUri: 'com.tianxuan.app://callback',
        state: 's1',
      );
      final uri = Uri.parse(url);
      expect(uri.path, '/login/oauth/authorize');
      expect(uri.queryParameters['provider'], 'GitHub');
    });
  });
}
