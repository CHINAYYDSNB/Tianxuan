import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/services/casdoor_service.dart';
import 'package:tianxuan/services/storage_service.dart';

String _makeIdToken(Map<String, dynamic> payload) {
  final enc = (String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  final header = enc('{"alg":"RS256","typ":"JWT"}');
  final body = enc(jsonEncode(payload));
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CasdoorService PKCE', () {
    test('buildPkce 生成 verifier/challenge/state', () {
      final pkce = CasdoorService.buildPkce();
      expect(pkce.verifier.length, 64);
      expect(pkce.state.isNotEmpty, isTrue);
      expect(pkce.challenge.length, isPositive);
      expect(pkce.challenge, isNot(pkce.verifier));
    });

    test('两次 buildPkce 结果不同（随机性）', () {
      final a = CasdoorService.buildPkce();
      final b = CasdoorService.buildPkce();
      expect(a.verifier, isNot(b.verifier));
      expect(a.challenge, isNot(b.challenge));
    });
  });

  group('CasdoorService buildAuthUrl', () {
    test('构建正确的授权 URL', () {
      final url = CasdoorService.buildAuthUrl(
        verifier: 'v' * 64,
        challenge: 'challenge123',
        state: 'state123',
        redirectUri: 'com.tianxuan.app://callback',
      );
      final uri = Uri.parse(url);
      expect(uri.host, 'logto.lingqi.vip');
      expect(uri.path, '/login/oauth/authorize');
      expect(uri.queryParameters['client_id'], '2eb37714fa37f170af58');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['scope'], 'openid profile email');
      expect(uri.queryParameters['state'], 'state123');
      expect(uri.queryParameters['code_challenge'], 'challenge123');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(
        uri.queryParameters['redirect_uri'],
        'com.tianxuan.app://callback',
      );
    });
  });

  group('CasdoorService token', () {
    test('exchangeCode state 不匹配返回 false', () async {
      final ok = await CasdoorService.exchangeCode(
        code: 'c',
        verifier: 'v',
        redirectUri: 'r',
        state: 'wrong',
        expectedState: 'expected',
      );
      expect(ok, isFalse);
    });

    test('getUserInfo 从 ID token 解码用户信息', () async {
      // 预置 access_token + id_token（通过 StorageService 写入）
      final idToken = _makeIdToken({
        'sub': 'u123',
        'name': '张三',
        'email': 'a@b.com',
        'picture': 'http://img/a.png',
      });
      await StorageService.instance.saveLogtoTokens(
        accessToken: 'at',
        idToken: idToken,
        expiresIn: 3600,
      );
      final info = await CasdoorService.getUserInfo();
      expect(info, isNotNull);
      expect(info!.sub, 'u123');
      expect(info.name, '张三');
      expect(info.email, 'a@b.com');
      expect(info.picture, 'http://img/a.png');
    });

    test('getUserInfo 无 token 返回 null', () async {
      final info = await CasdoorService.getUserInfo();
      expect(info, isNull);
    });

    test('isLoggedIn 无 token 为 false', () async {
      expect(await CasdoorService.isLoggedIn, isFalse);
    });

    test('refreshAccessToken 无 refresh_token 返回 false', () async {
      expect(await CasdoorService.refreshAccessToken(), isFalse);
    });
  });
}
