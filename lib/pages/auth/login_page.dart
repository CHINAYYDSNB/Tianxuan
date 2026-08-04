import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/casdoor_service.dart';
import 'casdoor_webview_page.dart';

/// 简约纯白登录入口页
///
/// 登录 / 注册 / 快捷登录均通过应用内 webview 打开 Casdoor 官方页面完成
/// （自带邮箱登录、GEETEST 人机验证、快捷登录）。
class AuthLoginPage extends ConsumerStatefulWidget {
  const AuthLoginPage({super.key});

  @override
  ConsumerState<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends ConsumerState<AuthLoginPage> {
  List<CasdoorProvider> _providers = [];
  bool _loadingProviders = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final providers = await CasdoorService.getLoginProviders();
    if (!mounted) return;
    setState(() {
      _providers = providers.where((p) => p.isOAuthProvider).toList();
      _loadingProviders = false;
    });
  }

  /// 打开 webview 登录页，成功后关闭本页
  Future<void> _openLogin() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CasdoorWebviewPage()),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 快捷登录：webview 打开指定第三方授权页
  Future<void> _loginWithProvider(String providerName) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CasdoorWebviewPage(providerName: providerName),
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oauthProviders = _providers;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('登录', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Logo + 标题
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C1014),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.terminal,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tianxuan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1014),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '1Panel 服务器管理',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const Spacer(flex: 2),

              // 邮箱登录主入口
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _openLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0C1014),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '邮箱登录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 快捷登录
              if (_loadingProviders)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (oauthProviders.isNotEmpty) ...[
                Row(
                  children: [
                    const Expanded(child: Divider(color: Colors.grey)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '快捷登录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: oauthProviders
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _ProviderIconButton(
                            provider: p,
                            onTap: () => _loginWithProvider(p.name),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // 注册
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '还没有账号？',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const CasdoorWebviewPage(signup: true),
                        ),
                      );
                      if (ok == true && mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text(
                      '注册',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0C1014),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '登录后可加密备份数据，并同步服务器鉴权',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷登录图标按钮
class _ProviderIconButton extends StatelessWidget {
  final CasdoorProvider provider;
  final VoidCallback onTap;

  const _ProviderIconButton({required this.provider, required this.onTap});

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
      case 'weibo':
        return Icons.public;
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
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(_icon, size: 24, color: const Color(0xFF0C1014)),
        ),
      ),
    );
  }
}
