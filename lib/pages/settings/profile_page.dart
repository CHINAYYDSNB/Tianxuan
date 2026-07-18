import 'package:flutter/material.dart';
import '../../services/logto_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String _userId = '';
  String _name = '';
  String _email = '';
  String _avatarUrl = '';
  late TextEditingController _nameCtrl;
  late TextEditingController _avatarCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _avatarCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final info = await LogtoService.getUserInfo();
    if (mounted) {
      setState(() {
        if (info != null) {
          _userId = info.sub;
          _name = info.name;
          _email = info.email;
          _avatarUrl = info.picture;
          _nameCtrl.text = _name;
          _avatarCtrl.text = _avatarUrl;
        }
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameCtrl.text.trim();
    final newAvatar = _avatarCtrl.text.trim();

    if (newName == _name && newAvatar == _avatarUrl) return;
    if (newName.isEmpty && newAvatar.isEmpty) return;

    setState(() => _saving = true);
    final ok = await LogtoService.updateProfile(
      userId: _userId,
      name: newName.isNotEmpty ? newName : null,
      avatar: newAvatar.isNotEmpty ? newAvatar : null,
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) {
          if (newName.isNotEmpty) _name = newName;
          if (newAvatar.isNotEmpty) _avatarUrl = newAvatar;
        }
      });
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('登出')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await LogtoService.logout();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('个人资料')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primary.withAlpha(20),
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty
                        ? Icon(Icons.person, size: 48, color: theme.colorScheme.primary)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(_name.isNotEmpty ? _name : '未设置昵称',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (_email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_email, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF686F78))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Edit form
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
                    controller: TextEditingController(text: _email.isNotEmpty ? _email : '未绑定'),
                  ),
                  const SizedBox(height: 4),
                  Text('邮箱由 Logto 管理，如需修改请联系管理员',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4BF))),
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
                              onPressed: () => setState(() => _avatarUrl = _avatarCtrl.text.trim()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text('输入图片 URL，点击右侧刷新图标预览',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4BF))),
                  const SizedBox(height: 4),
                  Text('哎呀，上传图片什么的。。。。。。有服务器了再说嘛',
                      style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFAAB4BF), fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _saveProfile,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save, size: 18),
                      label: Text(_saving ? '保存中...' : '保存修改'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout
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
}
