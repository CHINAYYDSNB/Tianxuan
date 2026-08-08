import 'package:flutter/material.dart';
import '../../api/database_api.dart';
import '../../theme/app_colors.dart';

/// 添加远程数据库连接（对齐 Mono-Dash：name/type/from/version/address/port/username/password）。
Future<void> showDatabaseRemoteCreateSheet(
  BuildContext context, {
  required String dbType,
  required Future<void> Function() onSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RemoteCreateSheet(dbType: dbType, onSuccess: onSuccess),
  );
}

class _RemoteCreateSheet extends StatefulWidget {
  final String dbType;
  final Future<void> Function() onSuccess;

  const _RemoteCreateSheet({required this.dbType, required this.onSuccess});

  @override
  State<_RemoteCreateSheet> createState() => _RemoteCreateSheetState();
}

class _RemoteCreateSheetState extends State<_RemoteCreateSheet> {
  late final _nameCtrl = TextEditingController();
  late final _addressCtrl = TextEditingController();
  late final _portCtrl = TextEditingController();
  late final _userCtrl = TextEditingController();
  late final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _portCtrl.text = switch (widget.dbType) {
      'postgresql' => '5432',
      _ => '3306',
    };
    _userCtrl.text = widget.dbType == 'postgresql' ? 'postgres' : 'root';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _body() => {
    'name': _nameCtrl.text.trim(),
    'type': widget.dbType,
    'from': 'remote',
    'version': '',
    'address': _addressCtrl.text.trim(),
    'port': int.tryParse(_portCtrl.text.trim()) ?? 3306,
    'username': _userCtrl.text.trim(),
    'password': _passCtrl.text,
    'timeout': 30,
    'description': '',
  };

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return '请输入连接名称';
    if (_addressCtrl.text.trim().isEmpty) return '请输入地址';
    if (_userCtrl.text.trim().isEmpty) return '请输入用户名';
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port < 1 || port > 65535) return '端口范围 1-65535';
    return null;
  }

  Future<void> _test() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await DatabaseApi.checkRemoteConnection(_body());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '连接正常' : '连接失败'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DatabaseApi.createRemoteDatabase(_body());
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (widget.dbType) {
      'postgresql' => 'PostgreSQL',
      'mariadb' => 'MariaDB',
      _ => 'MySQL',
    };
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
            Text(
              '添加 $typeLabel 远程连接',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '通过 1Panel 中转连接远程数据库实例',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '连接名称',
                border: OutlineInputBorder(),
                hintText: '如 prod-mysql',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: '地址',
                border: OutlineInputBorder(),
                hintText: 'db.example.com 或 IP',
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
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _test,
                    icon: const Icon(Icons.wifi_tethering, size: 18),
                    label: const Text('测试连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
