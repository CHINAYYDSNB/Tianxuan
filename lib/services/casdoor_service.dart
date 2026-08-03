// Casdoor OIDC 认证服务
// 认证端点: https://logto.lingqi.vip/（Casdoor 1.503）
// 授权: /login/oauth/authorize
// Token: /api/login/oauth/access_token
// 用户信息: /api/userinfo
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class CasdoorService {
  static const _base = 'https://logto.lingqi.vip';
  static const _authEndpoint = '$_base/login/oauth/authorize';
  static const _tokenEndpoint = '$_base/api/login/oauth/access_token';
  static const _userinfoEndpoint = '$_base/api/userinfo';

  static const _clientId = '2eb37714fa37f170af58';
  static const _clientSecret = '06e4cde32f530421187f51404fb914aacf2b2d37';
  static const _scopes = 'openid profile email';
  // Casdoor 应用标识：{组织}/{应用}。组织与应用均为 Tianxuan。
  static const _applicationId = 'Tianxuan/Tianxuan';

  /// 生成 PKCE 参数（Casdoor 支持 S256）
  static ({String verifier, String challenge, String state}) buildPkce() {
    final verifier = _randomBase64(64);
    final challenge = _sha256Base64Url(verifier);
    final state = verifier.substring(0, 32);
    return (verifier: verifier, challenge: challenge, state: state);
  }

  /// 构建 Casdoor 授权 URL
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
      'applicationId': _applicationId,
    };
    return Uri.parse(_authEndpoint).replace(queryParameters: params).toString();
  }

  /// 密码模式登录（skill 方式 B，App 内直接输账号密码）
  static Future<bool> loginWithPassword({
    required String username,
    required String password,
  }) async {
    try {
      final uri = Uri.parse(_tokenEndpoint).replace(
        queryParameters: {
          'grant_type': 'password',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'username': username,
          'password': password,
          'scope': _scopes,
        },
      );
      final resp = await http.post(uri);
      if (resp.statusCode != 200) return false;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      await StorageService.instance.saveLogtoTokens(
        accessToken: data['access_token']?.toString() ?? '',
        refreshToken: data['refresh_token']?.toString() ?? '',
        idToken: data['id_token']?.toString() ?? '',
        expiresIn: data['expires_in'] as int? ?? 3600,
      );
      return data['access_token']?.toString().isNotEmpty == true;
    } catch (_) {
      return false;
    }
  }

  /// 用 refresh_token 刷新 access_token（skill 5.4）
  static Future<bool> refreshAccessToken() async {
    final refreshToken = await StorageService.instance.getLogtoRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final uri = Uri.parse(_tokenEndpoint).replace(
        queryParameters: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
          'scope': _scopes,
        },
      );
      final resp = await http.post(uri);
      if (resp.statusCode != 200) {
        // refresh 失效 → 清除 token，需重新登录
        await StorageService.instance.deleteLogtoTokens();
        return false;
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      await StorageService.instance.saveLogtoTokens(
        accessToken: data['access_token']?.toString() ?? '',
        refreshToken: data['refresh_token']?.toString() ?? refreshToken,
        idToken: data['id_token']?.toString() ?? '',
        expiresIn: data['expires_in'] as int? ?? 3600,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 交换 authorization code → tokens（Casdoor 用 query 参数）
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
        Uri.parse(_tokenEndpoint).replace(
          queryParameters: {
            'grant_type': 'authorization_code',
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'code': code,
            'redirect_uri': redirectUri,
            'code_verifier': verifier,
          },
        ),
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

  /// 获取用户信息（userinfo endpoint）
  static Future<({String sub, String name, String email, String picture})?>
  getUserInfo() async {
    final token = await StorageService.instance.getLogtoAccessToken();
    if (token == null || token.isEmpty) return null;

    // 优先从 ID token 解码（无需网络）
    final idToken = await StorageService.instance.getLogtoIdToken();
    if (idToken != null && idToken.isNotEmpty) {
      final fromId = _decodeIdToken(idToken);
      if (fromId != null) return fromId;
    }

    // 回退 userinfo endpoint
    try {
      final resp = await http.get(
        Uri.parse(_userinfoEndpoint),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        return (
          sub: (data['sub'] ?? data['id'] ?? '').toString(),
          name:
              (data['name'] ??
                      data['displayName'] ??
                      data['preferred_username'] ??
                      '')
                  .toString(),
          email: (data['email'] ?? '').toString(),
          picture: (data['picture'] ?? '').toString(),
        );
      }
    } catch (_) {}

    return null;
  }

  static ({String sub, String name, String email, String picture})?
  _decodeIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      while (payload.length % 4 != 0) payload += '=';
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return (
        sub: (json['sub'] ?? '').toString(),
        name:
            (json['name'] ??
                    json['preferred_username'] ??
                    json['username'] ??
                    '')
                .toString(),
        email: (json['email'] ?? '').toString(),
        picture: (json['picture'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// 检查是否已登录
  static Future<bool> get isLoggedIn async {
    final token = await StorageService.instance.getLogtoAccessToken();
    final valid = await StorageService.instance.getLogtoTokenValid();
    return (token?.isNotEmpty == true) && valid;
  }

  /// 登出 — 清除本地 token（简单实现，不跳转登出页）
  static Future<void> logout() async {
    await StorageService.instance.deleteLogtoTokens();
    await StorageService.instance.clearLogtoPending();
  }

  /// 更新用户资料（Casdoor 管理 API，可能无权限）
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
      final resp = await http.post(
        Uri.parse('$_base/api/update-user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': userId, ...body}),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
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
