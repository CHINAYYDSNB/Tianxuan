import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/file_api.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';

/// 慢查询日志配置页（开关/阈值/记录查看）。
class DatabaseSlowLogPage extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const DatabaseSlowLogPage({super.key, required this.inst});

  @override
  ConsumerState<DatabaseSlowLogPage> createState() => _SlowLogPageState();
}

class _SlowLogPageState extends ConsumerState<DatabaseSlowLogPage> {
  final _thresholdCtrl = TextEditingController();
  bool _enabled = false;
  bool _loading = true;
  Object? _error;
  bool _saving = false;

  DatabaseService get _svc => ref.read(databaseServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vars = await _svc.loadVariables(widget.inst);
      if (!mounted) return;
      setState(() {
        _enabled =
            vars.slowQueryLog?.toLowerCase() == 'on' ||
            vars.slowQueryLog == '1';
        _thresholdCtrl.text = vars.longQueryTime ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final time = double.tryParse(_thresholdCtrl.text.trim());
    if (time == null || time < 0) {
      _snack('请输入有效的阈值秒数');
      return;
    }
    setState(() => _saving = true);
    try {
      final variables = <Map<String, dynamic>>[];
      variables.add({
        'key': 'slow_query_log',
        'value': _enabled ? 'ON' : 'OFF',
      });
      variables.add({
        'key': 'long_query_time',
        'value': _thresholdCtrl.text.trim(),
      });
      await _svc.updateVariables(widget.inst, variables);
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('已保存', green: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('保存失败: $e');
    }
  }

  Future<void> _viewLogs() async {
    try {
      final res = await FileApi.readByLineFile(
        type: '${widget.inst.type.apiType}-slow-logs',
        name: widget.inst.name,
        page: 1,
        pageSize: 500,
        latest: true,
      );
      if (!mounted) return;
      if (res.lines.isEmpty) {
        _snack('暂无慢查询记录');
        return;
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('慢查询日志'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                res.lines.join('\n'),
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _snack('读取失败: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('慢查询日志'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text('$_error', style: const TextStyle(color: Colors.red)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.slow_motion_video),
                        title: const Text('启用慢查询日志'),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Expanded(child: Text('阈值（秒）')),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: _thresholdCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '超过设定阈值秒数的 SQL 将被记录，可用于定位慢查询。',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.visibility_outlined),
                      title: const Text('查看记录'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _viewLogs,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
