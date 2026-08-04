import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/logto_auth_provider.dart';
import '../../services/casdoor_service.dart';
import '../../services/geetest_service.dart';

/// Casdoor 原生注册页：邮箱 + 用户名 + 密码 + GEETEST 验证
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _captchaVerified = false;
  String? _captchaId;

  @override
  void initState() {
    super.initState();
    _loadCaptchaId();
  }

  Future<void> _loadCaptchaId() async {
    final providers = await CasdoorService.getLoginProviders();
    if (!mounted) return;
    String? captchaId;
    for (final p in providers) {
      if (p.isCaptchaProvider) {
        captchaId = p.clientId;
        break;
      }
    }
    // 兜底：Casdoor 未配置 GEETEST provider 时用默认 captchaId
    setState(() {
      _captchaId = (captchaId != null && captchaId.isNotEmpty)
          ? captchaId
          : GeeTestService.defaultCaptchaId;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

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
      setState(() => _captchaVerified = true);
      return;
    }
    final result = await GeeTestService.verify(captchaId);
    if (!mounted) return;
    if (result != null) {
      setState(() => _captchaVerified = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证通过')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证未完成，请重试')));
    }
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final username = _username.text.trim();
    final name = _name.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写邮箱、用户名和密码')));
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('邮箱格式不正确')));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码至少 6 位')));
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次输入的密码不一致')));
      return;
    }

    String? captchaToken;
    if (_captchaId != null && _captchaId!.isNotEmpty && _captchaVerified) {
      final result = await GeeTestService.verify(_captchaId!);
      captchaToken = result?.captchaToken;
    }

    setState(() => _loading = true);
    final result = await ref
        .read(logtoAuthProvider.notifier)
        .signup(
          email: email,
          username: username,
          password: password,
          name: name,
          captchaToken: captchaToken,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('注册成功，已登录')));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '注册失败，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goBrowserSignup() {
    ref.read(logtoAuthProvider.notifier).signupViaBrowser();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Icon(
            Icons.person_add_alt,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            '创建 Tianxuan 账号',
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
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '昵称（可选）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            onSubmitted: (_) => _register(),
            decoration: const InputDecoration(
              labelText: '确认密码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_reset),
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
              onPressed: _loading ? null : _register,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_loading ? '注册中...' : '注册'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loading ? null : _goBrowserSignup,
            icon: const Icon(Icons.language),
            label: const Text('使用浏览器注册'),
          ),
          const SizedBox(height: 16),
          Text(
            '注册即表示同意服务条款与隐私政策',
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
