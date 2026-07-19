// TODO: Logto OIDC 已知问题 (2026-07-20)
// 1. PKCE flow 可能因 redirect URI 不匹配导致 code_verifier 校验失败
// 2. Web 平台 token 静默刷新未处理跨域 cookie
// 3. Session 过期后 UI 无感知，操作失败才报错
// 当前状态: Login entry points removed from first-launch, cloud backup, about page.
//   底层文件保留但不可达。logtoAuthProvider 是唯一状态源 (2026-07-19 refactored).
// See: [[tianxuan-logto-issues]]
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class LogtoService {
  static String get _clientId => kIsWeb
      ? 'pti5kd1hbra1svpzaq9em'
      : 'wgfs6xi6v7815b0mdfxwn';
  static const _authEndpoint = 'https://logto.lingqi.vip/oidc/auth';
  static const _tokenEndpoint = 'https://logto.lingqi.vip/oidc/token';
  static const _scopes = 'openid profile email';

  /// 生成 PKCE 参数
  static ({String verifier, String challenge, String state}) buildPkce() {
    final verifier = _randomBase64(64);
    final challenge = _sha256Base64Url(verifier);
    final state = verifier.substring(0, 32);
    return (verifier: verifier, challenge: challenge, state: state);
  }

  /// 构建 Logto 授权 URL
  static String buildAuthUrl({
    required String verifier,
    required String challenge,
    required String state,
    required String redirectUri,
  }) {
    final params = {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes,
      'state': state,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
    };
    return Uri.parse(_authEndpoint).replace(queryParameters: params).toString();
  }

  /// 交换 authorization code → tokens
  static Future<bool> exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
    required String state,
    String? expectedState,
  }) async {
    if (state != expectedState) return false;

    try {
      final resp = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': _clientId,
          'code_verifier': verifier,
        },
      );

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        await StorageService.instance.saveLogtoTokens(
          accessToken: data['access_token']?.toString() ?? '',
          refreshToken: data['refresh_token']?.toString() ?? '',
          idToken: data['id_token']?.toString() ?? '',
          expiresIn: data['expires_in'] as int? ?? 3600,
        );
        return true;
      }
    } catch (_) {}

    return false;
  }

  static const _managementApi = 'https://logto.lingqi.vip/api';

  /// 从 ID Token 解码用户信息
  static Future<({String sub, String name, String email, String picture})?> getUserInfo() async {
    final idToken = await StorageService.instance.getLogtoIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      while (payload.length % 4 != 0) payload += '=';
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return (
        sub: (json['sub'] ?? '').toString(),
        name: (json['name'] ?? json['username'] ?? json['preferred_username'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        picture: (json['picture'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// 更新 Logto 用户资料（name / avatar）
  static Future<bool> updateProfile({
    required String userId,
    String? name,
    String? avatar,
  }) async {
    final token = await StorageService.instance.getLogtoAccessToken();
    if (token == null || token.isEmpty) return false;
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatar != null) body['avatar'] = avatar;
      if (body.isEmpty) return false;

      final resp = await http.patch(
        Uri.parse('$_managementApi/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// 检查是否已登录
  static Future<bool> get isLoggedIn async {
    final token = await StorageService.instance.getLogtoAccessToken();
    final valid = await StorageService.instance.getLogtoTokenValid();
    return (token?.isNotEmpty == true) && valid;
  }

  /// 登出 — 清除本地 token
  static Future<void> logout() async {
    await StorageService.instance.deleteLogtoTokens();
    await StorageService.instance.clearLogtoPending();
  }

  static String _randomBase64(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '').substring(0, length);
  }

  static String _sha256Base64Url(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
}
