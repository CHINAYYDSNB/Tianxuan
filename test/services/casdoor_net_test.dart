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

  group('CasdoorService.refreshAccessToken', () {
    test('刷新成功更新 token', () async {
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'old',
        refreshToken: 'rt',
        expiresIn: 3600,
      );
      stub['/api/login/oauth/access_token'] = {
        'access_token': 'new_at',
        'refresh_token': 'new_rt',
        'expires_in': 7200,
      };
      expect(await CasdoorService.refreshAccessToken(), isTrue);
      expect(await StorageService.instance.getLogtoAccessToken(), 'new_at');
    });

    test('刷新失败清除 token', () async {
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'old',
        refreshToken: 'rt',
        expiresIn: 3600,
      );
      stub['/api/login/oauth/access_token'] = {'code': 401};
      expect(await CasdoorService.refreshAccessToken(), isFalse);
      expect(await StorageService.instance.getLogtoAccessToken(), isNull);
    });
  });

  group('CasdoorService.updateProfile', () {
    test('无 token 返回 false', () async {
      expect(
        await CasdoorService.updateProfile(userId: 'u1', name: 'x'),
        isFalse,
      );
    });

    test('更新成功返回 true', () async {
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'at',
        expiresIn: 3600,
      );
      stub['/api/update-user'] = {'code': 200, 'data': null};
      expect(
        await CasdoorService.updateProfile(userId: 'u1', name: 'x'),
        isTrue,
      );
    });
  });

  group('CasdoorService.getUserInfo userinfo 回退', () {
    test('无 ID token 时走 userinfo endpoint', () async {
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'at',
        expiresIn: 3600,
      );
      stub['/api/userinfo'] = {
        'sub': 'u9',
        'name': 'Alice',
        'email': 'a@b.com',
        'picture': 'http://img/a.png',
      };
      final info = await CasdoorService.getUserInfo();
      expect(info, isNotNull);
      expect(info!.sub, 'u9');
      expect(info.email, 'a@b.com');
    });
  });
}
