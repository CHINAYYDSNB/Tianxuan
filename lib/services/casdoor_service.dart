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

/// Casdoor 登录提供商（快捷登录 / GEETEST 验证码等）
class CasdoorProvider {
  final String name;
  final String type;
  final String category;
  final String displayName;
  final String clientId;
  final String rule;

  const CasdoorProvider({
    required this.name,
    this.type = '',
    this.category = '',
    this.displayName = '',
    this.clientId = '',
    this.rule = '',
  });

  /// 是否为 OAuth 第三方快捷登录（GitHub/Google/QQ/WeChat 等）
  bool get isOAuthProvider => category == 'OAuth';

  /// 是否为 GEETEST 验证码提供方
  bool get isCaptchaProvider => category == 'Captcha' && type == 'GEETEST';

  /// 图标名（用于快捷登录按钮）
  String get iconKey => type.toLowerCase().replaceAll(' ', '');

  factory CasdoorProvider.fromJson(Map<String, dynamic> json) {
    final provider = json['provider'];
    final p = provider is Map ? Map<String, dynamic>.from(provider) : null;
    String s(String key) => json[key]?.toString() ?? '';
    return CasdoorProvider(
      name: s('name'),
      type: p?['type']?.toString() ?? s('type'),
      category: p?['category']?.toString() ?? s('category'),
      displayName: p?['displayName']?.toString() ?? s('displayName'),
      clientId: p?['clientId']?.toString() ?? s('clientId'),
      rule: s('rule'),
    );
  }
}

/// 用户账户资料（来自 /api/get-account）
class CasdoorAccount {
  final String id;
  final String name;
  final String displayName;
  final String avatar;
  final String email;
  final bool emailVerified;
  final String phone;
  final List<String> linkedProviders;

  const CasdoorAccount({
    this.id = '',
    this.name = '',
    this.displayName = '',
    this.avatar = '',
    this.email = '',
    this.emailVerified = false,
    this.phone = '',
    this.linkedProviders = const [],
  });

  bool get hasEmail => email.isNotEmpty;

  factory CasdoorAccount.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    // 绑定的第三方账号：非空的 oauth 字段
    const oauthFields = [
      'github',
      'google',
      'qq',
      'wechat',
      'facebook',
      'dingtalk',
      'weibo',
      'gitee',
      'linkedin',
      'wecom',
      'lark',
      'gitlab',
      'apple',
      'azuread',
      'slack',
    ];
    final linked = oauthFields
        .where((f) => s(json[f]).isNotEmpty)
        .map((f) => f)
        .toList();
    final avatar = s(json['avatar']);
    final permanentAvatar = s(json['permanentAvatar']);
    return CasdoorAccount(
      id: s(json['id']),
      name: s(json['name']),
      displayName: s(json['displayName']),
      avatar: avatar.isNotEmpty ? avatar : permanentAvatar,
      email: s(json['email']),
      emailVerified: json['emailVerified'] == true,
      phone: s(json['phone']),
      linkedProviders: linked,
    );
  }
}

class CasdoorService {
  /// 测试注入用：可在测试中指向本地 mock server
  static String baseUrl = 'https://logto.lingqi.vip';
  static const _authEndpointPath = '/login/oauth/authorize';
  static const _tokenEndpointPath = '/api/login/oauth/access_token';
  static const _userinfoEndpointPath = '/api/userinfo';
  static const _appLoginEndpointPath = '/api/get-app-login';
  static const _loginEndpointPath = '/api/login';
  static const _signupEndpointPath = '/api/signup';
  static const _accountEndpointPath = '/api/get-account';

  static const _clientId = '2eb37714fa37f170af58';
  static const _clientSecret = '06e4cde32f530421187f51404fb914aacf2b2d37';
  static const _scopes = 'openid profile email';
  // Casdoor 应用标识：{组织}/{应用}。组织与应用均为 Tianxuan。
  static const _applicationId = 'Tianxuan/Tianxuan';
  static const _applicationName = 'Tianxuan';
  static const _organization = 'Tianxuan';

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
    return Uri.parse(
      '$baseUrl$_authEndpointPath',
    ).replace(queryParameters: params).toString();
  }

  /// 构建第三方快捷登录授权 URL
  static String buildProviderAuthUrl({
    required String providerName,
    required String redirectUri,
    required String state,
  }) {
    final params = {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scopes,
      'state': state,
      'applicationId': _applicationId,
      'provider': providerName,
    };
    return Uri.parse(
      '$baseUrl$_authEndpointPath',
    ).replace(queryParameters: params).toString();
  }

  /// 构建注册页授权 URL（网页注册）
  static String buildSignupUrl({
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
    return Uri.parse(
      '$baseUrl$_signupEndpointPath',
    ).replace(queryParameters: params).toString();
  }

  /// 获取应用登录配置（快捷登录提供商 + GEETEST captchaId）
  /// GET /api/get-app-login?clientId=...&type=code
  static Future<List<CasdoorProvider>> getLoginProviders() async {
    final uri = Uri.parse('$baseUrl$_appLoginEndpointPath').replace(
      queryParameters: {
        'clientId': _clientId,
        'responseType': 'code',
        'redirectUri': '',
        'scope': _scopes,
        'state': _randomBase64(8),
        'type': 'code',
      },
    );
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['data'] is! Map) return [];
      final app = data['data'] as Map;
      final providers = app['providers'];
      if (providers is! List) return [];
      return providers
          .whereType<Map>()
          .map((e) => CasdoorProvider.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 邮箱 + 密码 + 极验验证码登录（Casdoor POST /api/login）
  /// 登录成功保存 tokens。
  static Future<bool> loginWithPassword({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': 'login',
        'application': _applicationName,
        'organization': _organization,
        'username': email,
        'password': password,
        'autoSignin': false,
      };
      if (captchaToken != null && captchaToken.isNotEmpty) {
        body['captchaType'] = 'GEETEST';
        body['captchaToken'] = captchaToken;
      }
      final resp = await http.post(
        Uri.parse('$baseUrl$_loginEndpointPath'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (resp.statusCode != 200) return false;
      final data = json.decode(resp.body) as Map<String, dynamic>;
      // Casdoor 返回：{status, msg, data: accessToken, data2: refreshToken}
      // （也兼容 {accessToken, refreshToken} 变体）
      final accessToken = (data['data']?.toString().isNotEmpty == true)
          ? data['data'].toString()
          : (data['accessToken']?.toString() ?? '');
      final refreshToken = (data['data2']?.toString().isNotEmpty == true)
          ? data['data2'].toString()
          : (data['refreshToken']?.toString() ?? '');
      if (accessToken.isNotEmpty) {
        await StorageService.instance.saveLogtoTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          idToken: data['idToken']?.toString() ?? '',
          expiresIn: 3600,
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 用 refresh_token 刷新 access_token（skill 5.4）
  static Future<bool> refreshAccessToken() async {
    final refreshToken = await StorageService.instance.getLogtoRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final uri = Uri.parse('$baseUrl$_tokenEndpointPath').replace(
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
        Uri.parse('$baseUrl$_tokenEndpointPath').replace(
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

  /// 原生注册（Casdoor POST /api/signup）
  static Future<({bool ok, String? message})> signup({
    required String email,
    required String username,
    required String password,
    String? name,
    String? phone,
    String? captchaToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': 'signup',
        'application': _applicationName,
        'organization': _organization,
        'username': username,
        'email': email,
        'password': password,
      };
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (captchaToken != null && captchaToken.isNotEmpty) {
        body['captchaType'] = 'GEETEST';
        body['captchaToken'] = captchaToken;
      }
      final resp = await http.post(
        Uri.parse('$baseUrl$_signupEndpointPath'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && (data['code'] ?? 200) == 200) {
        return (ok: true, message: data['msg']?.toString());
      }
      return (ok: false, message: data['msg']?.toString());
    } catch (_) {
      return (ok: false, message: null);
    }
  }

  /// 获取当前用户完整资料（GET /api/get-account）
  static Future<CasdoorAccount?> getAccount() async {
    final token = await StorageService.instance.getLogtoAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final resp = await http.get(
        Uri.parse('$baseUrl$_accountEndpointPath'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final user = data['data'];
        if (user is Map) {
          return CasdoorAccount.fromJson(Map<String, dynamic>.from(user));
        }
      }
    } catch (_) {}
    return null;
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
        Uri.parse('$baseUrl$_userinfoEndpointPath'),
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
        Uri.parse('$baseUrl/api/update-user'),
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
