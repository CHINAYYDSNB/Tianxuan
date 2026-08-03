import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/logto_auth_provider.dart';

/// Casdoor 登录页：密码模式 + 浏览器授权两种入口
class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
      return;
    }
    setState(() => _loading = true);
    final ok = await ref
        .read(logtoAuthProvider.notifier)
        .loginWithPassword(username, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录失败，请检查账号密码')));
    }
  }

  Future<void> _loginWithBrowser() async {
    setState(() => _loading = true);
    await ref.read(logtoAuthProvider.notifier).login();
    // 浏览器跳转后本页保持，回调返回后刷新
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            controller: _username,
            decoration: const InputDecoration(
              labelText: '用户名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _loginWithPassword(),
            decoration: const InputDecoration(
              labelText: '密码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _loading ? null : _loginWithPassword,
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
          const SizedBox(height: 12),
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
