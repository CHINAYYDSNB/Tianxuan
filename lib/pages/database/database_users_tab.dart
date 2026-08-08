import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// 数据库用户管理 Tab（MySQL/PG/Mongo）。
class DatabaseUsersTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const DatabaseUsersTab({super.key, required this.inst});

  @override
  ConsumerState<DatabaseUsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<DatabaseUsersTab> {
  DatabaseService get _svc => ref.read(databaseServiceProvider);

  Future<void> _createUser() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String permission = '%';
    String? database;
    bool superUser = false;
    List<String> dbOptions = [];

    if (widget.inst.fromApi && !widget.inst.type.isRedis) {
      try {
        dbOptions = await _loadDbNames();
      } catch (_) {}
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('创建/绑定用户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (widget.inst.type.isPostgres ||
                    widget.inst.type == DbType.mysql ||
                    widget.inst.type == DbType.mariadb) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: database,
                    decoration: const InputDecoration(
                      labelText: '数据库',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('（可选）')),
                      for (final d in dbOptions)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => setDlg(() => database = v),
                  ),
                  const SizedBox(height: 10),
                  if (!widget.inst.type.isPostgres)
                    DropdownButtonFormField<String>(
                      initialValue: permission,
                      decoration: const InputDecoration(
                        labelText: '访问权限',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: '%', child: Text('% 任意主机')),
                        DropdownMenuItem(
                          value: 'localhost',
                          child: Text('localhost 仅本机'),
                        ),
                      ],
                      onChanged: (v) => setDlg(() => permission = v ?? '%'),
                    ),
                ],
                if (widget.inst.type.isPostgres)
                  CheckboxListTile(
                    value: superUser,
                    onChanged: (v) => setDlg(() => superUser = v ?? false),
                    title: const Text('超级用户'),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('请输入用户名');
      return;
    }
    try {
      await _svc.bindUser(
        widget.inst,
        database: database ?? name,
        username: name,
        password: passCtrl.text,
        permission: permission,
        isSuperUser: superUser,
      );
      if (!mounted) return;
      _snack('用户已创建', green: true);
      ref.invalidate(databaseUsersProvider(widget.inst.id));
    } catch (e) {
      if (mounted) _snack('创建失败: $e');
    }
  }

  Future<List<String>> _loadDbNames() async {
    final items = await ref
        .read(databaseServiceProvider)
        .searchDatabases(widget.inst);
    return items
        .map((e) => e.instanceName.isNotEmpty ? e.instanceName : e.name)
        .toList();
  }

  Future<void> _deleteUser(DatabaseUserInfo user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定删除用户「${user.username}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteUser(widget.inst, user.username);
      if (!mounted) return;
      _snack('已删除', green: true);
      ref.invalidate(databaseUsersProvider(widget.inst.id));
    } catch (e) {
      if (mounted) _snack('删除失败: $e');
    }
  }

  void _snack(String msg, {bool green = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: green ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(databaseUsersProvider(widget.inst.id));
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.inst.type.label} 用户',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.invalidate(databaseUsersProvider(widget.inst.id)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无用户，点击右下角创建',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final user = users[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            user.username,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '@${user.host}'
                            '${user.isSuperUser ? ' · 超级用户' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () => _deleteUser(user),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$e',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(
                            databaseUsersProvider(widget.inst.id),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _createUser,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('创建用户'),
          ),
        ),
      ],
    );
  }
}
