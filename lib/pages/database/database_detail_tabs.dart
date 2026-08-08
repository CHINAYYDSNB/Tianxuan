import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/database_api.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

// ─── 状态 Tab ───

class DatabaseStatusTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const DatabaseStatusTab({super.key, required this.inst});

  @override
  ConsumerState<DatabaseStatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends ConsumerState<DatabaseStatusTab> {
  bool _showEditor = false;

  Future<void> _saveConfig(String file) async {
    try {
      await ref
          .read(databaseServiceProvider)
          .updateConfigFile(widget.inst, file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) _showErr(e);
    }
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(databaseStatusProvider(widget.inst.id));
    final configAsync = ref.watch(databaseConfigFileProvider(widget.inst.id));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '运行状态',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '刷新',
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () => ref.invalidate(
                        databaseStatusProvider(widget.inst.id),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                statusAsync.when(
                  data: (status) {
                    if (status.isEmpty) {
                      return Text(
                        '暂无状态数据',
                        style: TextStyle(color: AppColors.textMuted),
                      );
                    }
                    return Column(
                      children: status.entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      e.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (e, _) => Text(
                    '获取失败: $e',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.inst.type.isRedis) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '配置文件',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showEditor = !_showEditor),
                        icon: Icon(
                          _showEditor ? Icons.close : Icons.edit_outlined,
                          size: 16,
                        ),
                        label: Text(_showEditor ? '关闭' : '编辑'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  configAsync.when(
                    data: (file) => _showEditor
                        ? _ConfigEditor(initial: file, onSave: _saveConfig)
                        : Text(
                            file.isEmpty ? '暂无配置' : file,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Text(
                      '读取失败: $e',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConfigEditor extends StatefulWidget {
  final String initial;
  final Future<void> Function(String) onSave;

  const _ConfigEditor({required this.initial, required this.onSave});

  @override
  State<_ConfigEditor> createState() => _ConfigEditorState();
}

class _ConfigEditorState extends State<_ConfigEditor> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          maxLines: 14,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSave(_ctrl.text);
                  if (mounted) setState(() => _saving = false);
                },
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: const Text('保存配置'),
        ),
      ],
    );
  }
}

// ─── 设置 Tab ───

class DatabaseSettingsTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const DatabaseSettingsTab({super.key, required this.inst});

  @override
  ConsumerState<DatabaseSettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<DatabaseSettingsTab> {
  bool _busy = false;

  DatabaseService get _svc => ref.read(databaseServiceProvider);

  Future<void> _test() async {
    setState(() => _busy = true);
    final err = await _svc.testConnection(widget.inst);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null ? '连接正常' : '连接失败: $err'),
        backgroundColor: err == null ? Colors.green : Colors.red,
      ),
    );
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
      if (widget.inst.type.isRedis) {
        await _svc.changeRedisPassword(
          widget.inst,
          DatabaseApi.encodeValue(pass),
        );
      } else {
        await _svc.changePassword(widget.inst, pass);
      }
      await ref
          .read(databaseInstancesProvider.notifier)
          .update(widget.inst.copyWith(password: pass));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMysql =
        widget.inst.type == DbType.mysql || widget.inst.type == DbType.mariadb;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: const Text('测试连接'),
                subtitle: const Text('验证实例连接与凭据'),
                trailing: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _busy ? null : _test,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                onTap: _busy ? null : _changePassword,
              ),
              if (isMysql && !widget.inst.isRemote) ...[
                const Divider(height: 1),
                _RemoteAccessTile(inst: widget.inst),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '实例信息',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _kv('名称', widget.inst.name),
                _kv('类型', widget.inst.type.label),
                _kv('地址', widget.inst.displayAddress),
                _kv('用户', widget.inst.username),
                _kv(
                  '来源',
                  widget.inst.isRemote
                      ? '远程'
                      : widget.inst.fromApi
                      ? '1Panel'
                      : '手动',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            k,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _RemoteAccessTile extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const _RemoteAccessTile({required this.inst});

  @override
  ConsumerState<_RemoteAccessTile> createState() => _RemoteAccessTileState();
}

class _RemoteAccessTileState extends ConsumerState<_RemoteAccessTile> {
  late Future<bool> _future;
  bool? _remote;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<bool> _load() async {
    try {
      final v = await ref
          .read(databaseServiceProvider)
          .getRemoteAccess(widget.inst);
      if (mounted) setState(() => _remote = v);
      return v;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() => _remote = v);
    try {
      await ref
          .read(databaseServiceProvider)
          .updateRemoteAccess(widget.inst, v);
    } catch (e) {
      if (mounted) {
        setState(() => _remote = !v);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        final value = _remote ?? snap.data ?? false;
        return SwitchListTile(
          secondary: const Icon(Icons.public),
          title: const Text('允许远程访问'),
          subtitle: const Text('root 用户允许任意主机（%）连接'),
          value: value,
          onChanged: snap.connectionState == ConnectionState.waiting
              ? null
              : _toggle,
        );
      },
    );
  }
}
