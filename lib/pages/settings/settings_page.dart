import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../services/logto_service.dart';
import '../../services/logto_bridge.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import '../logto_login_page.dart';
import 'connection_test_page.dart';
import 'cloud_backup_page.dart';
import 'ai_config_page.dart';
import 'about_page.dart';
import 'profile_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  bool _loggedIn = false;
  bool _checking = true;
  String _displayName = '';
  String _avatarUrl = '';
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _listenDeepLinks();
    _refreshLoginState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb && !_loggedIn) {
      _checkDeepLinkOnResume();
    }
  }

  void _listenDeepLinks() {
    _linkSub = LogtoBridge.onCallback.listen((uri) async {
      final query = uri.queryParameters;
      final handled = await _processCallback(query['code'], query['state']);
      if (handled && mounted) _refreshLoginState();
    });
  }

  Future<void> _checkDeepLinkOnResume() async {
    try {
      final initial = await LogtoBridge.getInitialLink();
      if (initial != null) {
        final query = initial.queryParameters;
        final handled = await _processCallback(query['code'], query['state']);
        if (handled && mounted) _refreshLoginState();
      }
    } catch (_) {}
  }

  Future<bool> _processCallback(String? code, String? state) async {
    if (code == null || state == null) return false;
    final saved = await StorageService.instance.getLogtoPending();
    if (saved == null || state != saved['state']) return false;
    final ok = await LogtoService.exchangeCode(
      code: code, verifier: saved['verifier'] ?? '',
      redirectUri: LogtoBridge.callbackUri, state: state,
      expectedState: saved['state'],
    );
    if (ok) {
      await StorageService.instance.clearLogtoPending();
      return true;
    }
    return false;
  }

  Future<void> _refreshLoginState() async {
    final loggedIn = await LogtoService.isLoggedIn;
    String name = '';
    String avatar = '';
    if (loggedIn) {
      final info = await LogtoService.getUserInfo();
      if (info != null) {
        name = info.name;
        avatar = info.picture;
      }
    }
    if (mounted) setState(() {
      _loggedIn = loggedIn;
      _displayName = name;
      _avatarUrl = avatar;
      _checking = false;
    });
  }

  Future<void> _startLogin() async {
    try {
      final pkce = LogtoService.buildPkce();
      await StorageService.instance.saveLogtoPending(pkce.verifier, pkce.state);
      final url = LogtoService.buildAuthUrl(
        verifier: pkce.verifier,
        challenge: pkce.challenge,
        state: pkce.state,
        redirectUri: LogtoBridge.callbackUri,
      );

      if (kIsWeb) {
        await LogtoBridge.redirect(url);
      } else {
        if (!mounted) return;
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => LogtoLoginPage(
              child: const _LoginSuccessPlaceholder(),
            ),
          ),
        );
        if (result == true && mounted) _refreshLoginState();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开浏览器失败: $e')),
      );
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('登出'),
        content: const Text('确定要登出 Logto 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('登出')),
        ],
      ),
    );
    if (ok == true) {
      await LogtoService.logout();
      if (mounted) _refreshLoginState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══ Logto 登录卡片 ═══
          if (_checking)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            )
          else
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loggedIn
                    ? () async {
                        final loggedOut = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfilePage()),
                        );
                        if (loggedOut == true && mounted) _refreshLoginState();
                      }
                    : _startLogin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      if (_loggedIn && _avatarUrl.isNotEmpty)
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(_avatarUrl),
                        )
                      else
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: (_loggedIn ? Colors.green : Colors.orange).withAlpha(30),
                          child: Icon(
                            _loggedIn ? Icons.person : Icons.login,
                            color: _loggedIn ? Colors.green : Colors.orange,
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loggedIn ? _displayName : 'Logto 登录',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _loggedIn ? '已登录 — 点击登出' : '点击登录以加密备份数据',
                              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF686F78)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          _SettingsCard(
            icon: Icons.wifi_find,
            iconColor: Colors.blue,
            title: '连接检测',
            subtitle: connected ? '已连接服务器' : '未连接',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionTestPage())),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.cloud,
            iconColor: Colors.teal,
            title: '数据备份',
            subtitle: '备份/恢复服务器配置',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudBackupPage())),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.smart_toy,
            iconColor: Colors.purple,
            title: 'AI 配置',
            subtitle: 'OpenAI 兼容接口设置',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiConfigPage())),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.info_outline,
            iconColor: const Color(0xFF686F78),
            title: '关于',
            subtitle: 'Tianxuan ${UpdateService.currentVersion}',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
        ],
      ),
    );
  }
}

/// After native login success, this placeholder triggers a pop
class _LoginSuccessPlaceholder extends StatelessWidget {
  const _LoginSuccessPlaceholder();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pop(true);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withAlpha(30),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF686F78))),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
            ],
          ),
        ),
      ),
    );
  }
}
