import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/casdoor_service.dart';
import '../services/logto_bridge.dart';
import '../services/storage_service.dart';

/// Logto 认证状态 — 单一数据源
class LogtoAuthState {
  final bool isLoggedIn;
  final bool checking;
  final String userId;
  final String name;
  final String email;
  final String avatarUrl;
  final List<String> linkedProviders;
  final bool emailMissing;

  const LogtoAuthState({
    this.isLoggedIn = false,
    this.checking = true,
    this.userId = '',
    this.name = '',
    this.email = '',
    this.avatarUrl = '',
    this.linkedProviders = const [],
    this.emailMissing = false,
  });

  LogtoAuthState copyWith({
    bool? isLoggedIn,
    bool? checking,
    String? userId,
    String? name,
    String? email,
    String? avatarUrl,
    List<String>? linkedProviders,
    bool? emailMissing,
  }) => LogtoAuthState(
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    checking: checking ?? this.checking,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    linkedProviders: linkedProviders ?? this.linkedProviders,
    emailMissing: emailMissing ?? this.emailMissing,
  );
}

class LogtoAuthNotifier extends StateNotifier<LogtoAuthState> {
  StreamSubscription<Uri>? _linkSub;
  _LogtoLifecycleObserver? _observer;

  LogtoAuthNotifier() : super(const LogtoAuthState()) {
    _init();
  }

  Future<void> _init() async {
    // 恢复已有 token 登录态
    try {
      final loggedIn = await CasdoorService.isLoggedIn;
      if (loggedIn) {
        await refreshUserInfo();
        _setupListeners();
        return;
      }
    } catch (_) {}

    state = state.copyWith(checking: false);
    _setupListeners();
  }

  void _setupListeners() {
    if (kIsWeb) return;

    // EventChannel stream — 运行时 deep link
    _linkSub = LogtoBridge.onCallback.listen(_onDeepLink);

    // 冷启动 deep link
    LogtoBridge.getInitialLink().then((uri) {
      if (uri != null) _onDeepLink(uri);
    });

    // App 从后台恢复时检查 initial link (stream 可能漏事件)
    _observer = _LogtoLifecycleObserver(_onResume);
    WidgetsBinding.instance.addObserver(_observer!);
  }

  void _onResume() {
    if (state.isLoggedIn) return;
    LogtoBridge.getInitialLink().then((uri) {
      if (uri != null) _onDeepLink(uri);
    });
  }

  void _onDeepLink(Uri uri) {
    final code = uri.queryParameters['code'];
    final st = uri.queryParameters['state'];
    _processCallback(code, st);
  }

  Future<void> _processCallback(String? code, String? stateParam) async {
    if (code == null || stateParam == null) return;

    final saved = await StorageService.instance.getLogtoPending();
    if (saved == null || stateParam != saved['state']) {
      // pending 丢失 — 可能已由 exchangeCode 处理，检查 token
      await refreshUserInfo();
      return;
    }

    final ok = await CasdoorService.exchangeCode(
      code: code,
      verifier: saved['verifier'] ?? '',
      redirectUri: LogtoBridge.callbackUri,
      state: stateParam,
      expectedState: saved['state'],
    );

    if (ok) {
      if (kIsWeb) LogtoBridge.clearCallbackParams();
      await StorageService.instance.clearLogtoPending();
      await refreshUserInfo();
    } else {
      // exchangeCode 失败 — 可能 code 已被消费
      await refreshUserInfo();
    }
  }

  Future<void> refreshUserInfo() async {
    final loggedIn = await CasdoorService.isLoggedIn;
    if (!loggedIn) {
      state = state.copyWith(isLoggedIn: false, checking: false);
      return;
    }

    final info = await CasdoorService.getUserInfo();
    final account = await CasdoorService.getAccount();
    state = LogtoAuthState(
      isLoggedIn: true,
      checking: false,
      userId: info?.sub ?? account?.id ?? '',
      name: (info?.name.isNotEmpty == true)
          ? info!.name
          : (account?.displayName.isNotEmpty == true)
          ? account!.displayName
          : account?.name ?? '',
      email: info?.email.isNotEmpty == true
          ? info!.email
          : account?.email ?? '',
      avatarUrl: info?.picture.isNotEmpty == true
          ? info!.picture
          : account?.avatar ?? '',
      linkedProviders: account?.linkedProviders ?? const [],
      emailMissing:
          (info?.email.isNotEmpty != true) &&
          (account?.email.isNotEmpty != true),
    );
  }

  /// 发起 Logto 登录
  Future<void> login() async {
    try {
      final pkce = CasdoorService.buildPkce();
      await StorageService.instance.saveLogtoPending(pkce.verifier, pkce.state);
      final url = CasdoorService.buildAuthUrl(
        verifier: pkce.verifier,
        challenge: pkce.challenge,
        state: pkce.state,
        redirectUri: LogtoBridge.callbackUri,
      );
      await LogtoBridge.redirect(url);
    } catch (_) {}
  }

  /// 第三方快捷登录（provider 浏览器授权）
  Future<void> loginWithProvider(String providerName) async {
    try {
      final pkce = CasdoorService.buildPkce();
      await StorageService.instance.saveLogtoPending(pkce.verifier, pkce.state);
      final url = CasdoorService.buildProviderAuthUrl(
        providerName: providerName,
        redirectUri: LogtoBridge.callbackUri,
        state: pkce.state,
      );
      await LogtoBridge.redirect(url);
    } catch (_) {}
  }

  /// 网页注册（跳 Casdoor 注册页，自带验证码）
  Future<void> signupViaBrowser() async {
    try {
      final pkce = CasdoorService.buildPkce();
      await StorageService.instance.saveLogtoPending(pkce.verifier, pkce.state);
      final url = CasdoorService.buildSignupUrl(
        verifier: pkce.verifier,
        challenge: pkce.challenge,
        state: pkce.state,
        redirectUri: LogtoBridge.callbackUri,
      );
      await LogtoBridge.redirect(url);
    } catch (_) {}
  }

  /// 密码模式登录（邮箱 + 密码 + 极验验证）
  Future<bool> loginWithPassword(
    String email,
    String password, {
    String? captchaToken,
  }) async {
    final ok = await CasdoorService.loginWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
    if (ok) {
      await refreshUserInfo();
    }
    return ok;
  }

  /// 原生注册（邮箱 + 用户名 + 密码 + 极验验证）
  Future<({bool ok, String? message})> signup({
    required String email,
    required String username,
    required String password,
    String? name,
    String? captchaToken,
  }) async {
    final result = await CasdoorService.signup(
      email: email,
      username: username,
      password: password,
      name: name,
      captchaToken: captchaToken,
    );
    if (result.ok) {
      await refreshUserInfo();
    }
    return result;
  }

  /// 刷新 access_token（skill 5.4）
  Future<bool> refreshToken() async {
    final ok = await CasdoorService.refreshAccessToken();
    if (ok) {
      await refreshUserInfo();
    }
    return ok;
  }

  /// 登出
  Future<void> logout() async {
    await CasdoorService.logout();
    state = const LogtoAuthState(checking: false);
  }

  /// Web: 处理当前 URL 回调参数，返回 true 表示已处理
  Future<bool> handleWebCallback() async {
    if (!kIsWeb) return false;

    final code = LogtoBridge.extractCallbackParams()['code'];
    final st = LogtoBridge.extractCallbackParams()['state'];
    if (code == null || st == null) return false;

    await _processCallback(code, st);
    return true;
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    if (_observer != null) {
      WidgetsBinding.instance.removeObserver(_observer!);
    }
    super.dispose();
  }
}

class _LogtoLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  _LogtoLifecycleObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// 唯一 Logto 认证 provider — 全局单例，所有页面从这里读登录状态
final logtoAuthProvider =
    StateNotifierProvider<LogtoAuthNotifier, LogtoAuthState>((ref) {
      return LogtoAuthNotifier();
    });
