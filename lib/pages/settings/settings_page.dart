import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/logto_auth_provider.dart';
import '../../services/update_service.dart';
import 'cloud_backup_page.dart';
import 'ai_config_page.dart';
import 'about_page.dart';
import 'personalize_page.dart';
import 'profile_page.dart';
import '../auth/login_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(logtoAuthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // ═══ Logto 登录卡片 ═══
          if (auth.checking)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            )
          else
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: auth.isLoggedIn
                    ? () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        );
                      }
                    : () => _startLogin(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      if (auth.isLoggedIn && auth.avatarUrl.isNotEmpty)
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(auth.avatarUrl),
                        )
                      else if (auth.isLoggedIn)
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.green.withAlpha(30),
                          child: const Icon(Icons.person, color: Colors.green),
                        )
                      else
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: const AssetImage(
                            'assets/default_avatar.png',
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isLoggedIn ? auth.name : '账号登录',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.isLoggedIn
                                  ? (auth.emailMissing
                                        ? '已登录 — 未绑定邮箱，点击查看'
                                        : '已登录 — 点击管理账户')
                                  : '点击登录以加密备份数据',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: auth.isLoggedIn && auth.emailMissing
                                    ? Colors.orange
                                    : const Color(0xFF686F78),
                              ),
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
          const SizedBox(height: 10),
          // ═══ 数据备份 + AI 配置（合并卡片）═══
          Card(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.cloud_outlined,
                  title: '数据备份',
                  subtitle: '备份/恢复服务器配置',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CloudBackupPage()),
                  ),
                ),
                _SettingRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI 配置',
                  subtitle: 'OpenAI 兼容接口设置',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiConfigPage()),
                  ),
                ),
                _SettingRow(
                  icon: Icons.palette_outlined,
                  title: '个性化',
                  subtitle: '主题配色、背景',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PersonalizePage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: 'Tianxuan ${UpdateService.currentVersion}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
        ],
      ),
    );
  }
}

void _startLogin(BuildContext context, WidgetRef ref) {
  // 弹出登录页：密码模式 / 浏览器授权两种入口（skill casdoor-login-flutter）
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AuthLoginPage()),
  );
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
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
              Icon(icon, size: 22, color: const Color(0xFF0C1014)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF686F78),
                        ),
                      ),
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

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: const Color(0xFF0C1014)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF686F78),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
          ],
        ),
      ),
    );
  }
}
