import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// 数据库实例详情：库列表 + 创建/删除/改密/连接测试
class DatabaseDetailPage extends ConsumerStatefulWidget {
  final DatabaseInstance instance;
  const DatabaseDetailPage({super.key, required this.instance});

  @override
  ConsumerState<DatabaseDetailPage> createState() => _DatabaseDetailPageState();
}

class _DatabaseDetailPageState extends ConsumerState<DatabaseDetailPage> {
  late final DatabaseInstance _inst;
  List<DatabaseItem> _dbs = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _inst = widget.instance;
    _load();
  }

  DatabaseService get _svc => ref.read(databaseServiceProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _svc.listDatabases(_inst);
      if (!mounted) return;
      setState(() {
        _dbs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createDatabase() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建数据库'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '数据库名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _svc.createDatabase(_inst, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建成功'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (mounted) _showErr(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDatabase(DatabaseItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除数据库'),
        content: Text('确定删除数据库「${item.name}」吗？此操作不可恢复。'),
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
    setState(() => _busy = true);
    try {
      await _svc.deleteDatabase(_inst, item.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (mounted) _showErr(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final ctrl = TextEditingController();
    final pass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '新密码',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (pass == null || pass.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _svc.changePassword(_inst, pass);
      // 更新本地保存的密码
      await ref
          .read(databaseInstancesProvider.notifier)
          .update(_inst.copyWith(password: pass));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) _showErr(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _busy = true);
    final err = await _svc.testConnection(_inst);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? '连接正常' : '连接失败: $err'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ),
    );
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${_inst.name} · ${_inst.type.label}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // 实例信息
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _inst.displayAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_inst.username}${_inst.version.isNotEmpty ? ' · ${_inst.version}' : ''}'
                          '${_inst.fromApi ? ' · 1Panel' : ' · 手动'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _testConnection,
                              icon: const Icon(Icons.wifi_tethering, size: 16),
                              label: const Text('测试连接'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _changePassword,
                              icon: const Icon(Icons.lock_outline, size: 16),
                              label: const Text('修改密码'),
                            ),
                            FilledButton.icon(
                              onPressed: _busy ? null : _createDatabase,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('新建数据库'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 库列表
                Expanded(
                  child: _dbs.isEmpty
                      ? Center(
                          child: Text(
                            '暂无数据库',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          itemCount: _dbs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final db = _dbs[i];
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.storage_outlined),
                                title: Text(
                                  db.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: db.format.isNotEmpty
                                    ? Text(
                                        '${db.format} · ${db.username}',
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: '删除',
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteDatabase(db),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
