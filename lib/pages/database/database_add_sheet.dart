import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';

/// 手动添加数据库实例表单
Future<void> showDatabaseAddSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DatabaseAddSheet(ref: ref);
    },
  );
}

class DatabaseAddSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const DatabaseAddSheet({super.key, required this.ref});

  @override
  ConsumerState<DatabaseAddSheet> createState() => _DatabaseAddSheetState();
}

class _DatabaseAddSheetState extends ConsumerState<DatabaseAddSheet> {
  DbType _type = DbType.mysql;
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(text: 'localhost');
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _containerCtrl = TextEditingController();
  bool _inDocker = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _containerCtrl.dispose();
    super.dispose();
  }

  void _onTypeChange(DbType t) {
    setState(() {
      _type = t;
      _portCtrl.text = t.defaultPort.toString();
      _userCtrl.text = t.defaultUser;
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写实例名称')));
      return;
    }
    final inst = DatabaseInstance(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      name: name,
      address: _addressCtrl.text.trim().isEmpty
          ? 'localhost'
          : _addressCtrl.text.trim(),
      port: int.tryParse(_portCtrl.text.trim()) ?? _type.defaultPort,
      username: _userCtrl.text.trim().isEmpty
          ? _type.defaultUser
          : _userCtrl.text.trim(),
      password: _passCtrl.text,
      containerName: _containerCtrl.text.trim().isEmpty
          ? null
          : _containerCtrl.text.trim(),
      inDocker: _inDocker,
      source: 'manual',
    );
    await widget.ref.read(databaseInstancesProvider.notifier).add(inst);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '添加数据库实例',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '凭据仅保存在本机，优先使用 1Panel API，失败时通过 SSH 连接',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DbType>(
              segments: DbType.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (s) => _onTypeChange(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '实例名称',
                border: OutlineInputBorder(),
                hintText: '如 my-mysql',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: '地址',
                border: OutlineInputBorder(),
                hintText: 'localhost 或 IP',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Docker 容器'),
              subtitle: const Text('数据库运行在 Docker 容器中'),
              value: _inDocker,
              onChanged: (v) => setState(() => _inDocker = v),
            ),
            if (_inDocker) ...[
              TextField(
                controller: _containerCtrl,
                decoration: const InputDecoration(
                  labelText: '容器名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
