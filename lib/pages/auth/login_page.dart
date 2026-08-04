import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/logto_auth_provider.dart';
import '../../services/casdoor_service.dart';
import '../../services/geetest_service.dart';
import 'register_page.dart';

/// Casdoor 登录页：邮箱 + 密码 + GEETEST 验证 + 快捷登录 + 注册入口
class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _captchaVerified = false;
  String? _captchaId;
  List<CasdoorProvider> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final providers = await CasdoorService.getLoginProviders();
    if (!mounted) return;
    setState(() {
      _providers = providers;
      String? captchaId;
      for (final p in providers) {
        if (p.isCaptchaProvider) {
          captchaId = p.clientId;
          break;
        }
      }
      // 兜底：Casdoor 未配置 GEETEST provider 时用默认 captchaId
      _captchaId = (captchaId != null && captchaId.isNotEmpty)
          ? captchaId
          : GeeTestService.defaultCaptchaId;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 极验验证：验证通过后标记 _captchaVerified
  Future<void> _runCaptcha() async {
    final captchaId = _captchaId;
    if (captchaId == null || captchaId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未配置验证码，跳过验证')));
      setState(() => _captchaVerified = true);
      return;
    }
    if (!GeeTestService.isSupported) {
      // Web 无原生极验，标记通过（服务端仍会校验）
      setState(() => _captchaVerified = true);
      return;
    }
    final result = await GeeTestService.verify(captchaId);
    if (!mounted) return;
    if (result != null) {
      _captchaVerified = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证通过')));
    } else {
      _captchaVerified = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证未完成，请重试')));
    }
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入邮箱和密码')));
      return;
    }

    String? captchaToken;
    if (_captchaId != null && _captchaId!.isNotEmpty && _captchaVerified) {
      final result = await GeeTestService.verify(_captchaId!);
      captchaToken = result?.captchaToken;
    }

    setState(() => _loading = true);
    final ok = await ref
        .read(logtoAuthProvider.notifier)
        .loginWithPassword(email, password, captchaToken: captchaToken);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录失败，请检查邮箱密码或验证码')));
    }
  }

  Future<void> _loginWithProvider(String providerName) async {
    setState(() => _loading = true);
    await ref.read(logtoAuthProvider.notifier).loginWithProvider(providerName);
    // 浏览器跳转后本页保持，回调返回后刷新
  }

  Future<void> _loginWithBrowser() async {
    setState(() => _loading = true);
    await ref.read(logtoAuthProvider.notifier).login();
  }

  void _goRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oauthProviders = _providers.where((p) => p.isOAuthProvider).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('账号登录')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.account_circle,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            '登录 Tianxuan 账号',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: 'you@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _login(),
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          if (_captchaId != null && _captchaId!.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: _loading ? null : _runCaptcha,
              icon: Icon(
                _captchaVerified
                    ? Icons.verified
                    : Icons.verified_user_outlined,
                size: 18,
              ),
              label: Text(_captchaVerified ? '人机验证已通过' : '点击进行人机验证'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _captchaVerified
                    ? Colors.green
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _login,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_loading ? '登录中...' : '登录'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _goRegister,
              child: const Text('没有账号？立即注册'),
            ),
          ),
          const SizedBox(height: 16),

          if (oauthProviders.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '快捷登录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFAAB4BF),
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: oauthProviders
                  .map(
                    (p) => _ProviderButton(
                      provider: p,
                      onTap: _loading ? null : () => _loginWithProvider(p.name),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          TextButton.icon(
            onPressed: _loading ? null : _loginWithBrowser,
            icon: const Icon(Icons.language),
            label: const Text('使用浏览器登录'),
          ),
          const SizedBox(height: 24),
          Text(
            '登录后可加密备份数据，并同步服务器鉴权',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF686F78),
            ),
          ),
        ],
      ),
    );
  }
}

/// 第三方快捷登录按钮
class _ProviderButton extends StatelessWidget {
  final CasdoorProvider provider;
  final VoidCallback? onTap;

  const _ProviderButton({required this.provider, this.onTap});

  IconData get _icon {
    switch (provider.type.toLowerCase()) {
      case 'github':
        return Icons.code;
      case 'google':
        return Icons.g_mobiledata;
      case 'qq':
        return Icons.chat_bubble;
      case 'wechat':
      case 'wechatwork':
        return Icons.chat;
      case 'apple':
        return Icons.apple;
      case 'dingtalk':
        return Icons.work_outline;
      case 'facebook':
        return Icons.facebook;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = provider.displayName.isNotEmpty
        ? provider.displayName
        : provider.type;
    return Tooltip(
      message: '使用 $name 登录',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(_icon, size: 28),
          ),
        ),
      ),
    );
  }
}
