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
