import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/casdoor_service.dart';
import '../../providers/logto_auth_provider.dart';

/// 账户资料页：头像 / 昵称 / 邮箱 / 绑定的快捷登录项
/// 未绑定邮箱时提示用户绑定
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _avatarCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(logtoAuthProvider);
    _nameCtrl = TextEditingController(text: auth.name);
    _avatarCtrl = TextEditingController(text: auth.avatarUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final auth = ref.read(logtoAuthProvider);
    final newName = _nameCtrl.text.trim();
    final newAvatar = _avatarCtrl.text.trim();

    if (newName == auth.name && newAvatar == auth.avatarUrl) return;
    if (newName.isEmpty && newAvatar.isEmpty) return;

    setState(() => _saving = true);
    final ok = await CasdoorService.updateProfile(
      userId: auth.userId,
      name: newName.isNotEmpty ? newName : null,
      avatar: newAvatar.isNotEmpty ? newAvatar : null,
    );
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        ref.read(logtoAuthProvider.notifier).refreshUserInfo();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '资料已更新' : '更新失败，可能需要管理员权限'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(logtoAuthProvider.notifier).logout();
    }
  }

  /// 邮箱缺失时提示用户去 Casdoor 绑定邮箱
  void _promptBindEmail() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_unread_outlined, size: 40),
        title: const Text('尚未绑定邮箱'),
        content: const Text(
          '当前账号没有绑定邮箱，部分功能（如找回密码、通知）可能不可用。'
          '请登录 Casdoor 控制台在个人资料中绑定邮箱。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(logtoAuthProvider);

    if (auth.checking) {
      return Scaffold(
        appBar: AppBar(title: const Text('账户资料')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final linkedProviders = auth.linkedProviders;

    return Scaffold(
      appBar: AppBar(title: const Text('账户资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头像 / 昵称 / 邮箱
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primary.withAlpha(20),
                    backgroundImage: auth.avatarUrl.isNotEmpty
                        ? NetworkImage(auth.avatarUrl)
                        : null,
                    child: auth.avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 48,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    auth.name.isNotEmpty ? auth.name : '未设置昵称',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (auth.email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      auth.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF686F78),
                      ),
                    ),
                  ],
                  if (auth.emailMissing) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _promptBindEmail,
                      icon: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      label: const Text(
                        '未绑定邮箱，点击查看',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 绑定的快捷登录项
          if (linkedProviders.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('快捷登录绑定', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: linkedProviders
                          .map(
                            (p) => Chip(
                              avatar: Icon(_providerIcon(p), size: 18),
                              label: Text(_providerLabel(p)),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withAlpha(60),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '以上第三方账号与本账户已绑定',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF686F78),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 编辑资料
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('编辑资料', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      hintText: '输入新的昵称',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                    controller: TextEditingController(
                      text: auth.email.isNotEmpty ? auth.email : '未绑定',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.emailMissing
                        ? '未绑定邮箱，请在 Casdoor 控制台绑定'
                        : '邮箱由 Logto 管理，如需修改请联系管理员',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: auth.emailMissing
                          ? Colors.orange
                          : const Color(0xFFAAB4BF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.colorScheme.outline.withAlpha(40)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _avatarCtrl,
                    decoration: InputDecoration(
                      labelText: '头像 URL',
                      hintText: 'https://example.com/avatar.jpg',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.image_outlined, size: 20),
                      suffixIcon: _avatarCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: '预览',
                              onPressed: () => setState(() {}),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '输入图片 URL，点击右侧刷新图标预览',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFAAB4BF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_saving ? '保存中...' : '保存修改'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 登出
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('登出', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _providerIcon(String type) {
    switch (type) {
      case 'github':
        return Icons.code;
      case 'google':
        return Icons.g_mobiledata;
      case 'qq':
        return Icons.chat_bubble;
      case 'wechat':
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

  String _providerLabel(String type) {
    switch (type) {
      case 'github':
        return 'GitHub';
      case 'google':
        return 'Google';
      case 'qq':
        return 'QQ';
      case 'wechat':
        return '微信';
      case 'apple':
        return 'Apple';
      case 'dingtalk':
        return '钉钉';
      case 'facebook':
        return 'Facebook';
      case 'weibo':
        return '微博';
      case 'gitee':
        return 'Gitee';
      case 'linkedin':
        return 'LinkedIn';
      case 'wecom':
        return '企业微信';
      case 'lark':
        return '飞书';
      case 'gitlab':
        return 'GitLab';
      default:
        return type;
    }
  }
}
