import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/cronjob_api.dart';
import '../../providers/ssh_connection_provider.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// 计划任务页（1Panel API 优先，失败 fallback SSH crontab）
class ServerCronjobPage extends ConsumerStatefulWidget {
  const ServerCronjobPage({super.key});

  @override
  ConsumerState<ServerCronjobPage> createState() => _ServerCronjobPageState();
}

class _ServerCronjobPageState extends ConsumerState<ServerCronjobPage> {
  List<CronjobItem> _items = [];
  bool _loading = true;
  String? _error;
  bool _usingSsh = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // API 优先
    try {
      final items = await CronjobApi.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _usingSsh = false;
      });
      return;
    } catch (e) {
      // SSH fallback：crontab -l
      try {
        final ssh = ref.read(sshServiceProvider);
        if (ssh != null) {
          final res = await ssh.execute('crontab -l 2>/dev/null || echo ""');
          final parsed = _parseCrontab(res.stdout);
          if (!mounted) return;
          setState(() {
            _items = parsed;
            _loading = false;
            _usingSsh = true;
          });
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 从 crontab -l 输出解析任务（仅展示）
  List<CronjobItem> _parseCrontab(String output) {
    final result = <CronjobItem>[];
    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final parts = t.split(RegExp(r'\s+'));
      if (parts.length >= 6) {
        result.add(
          CronjobItem(
            name: 'crontab',
            type: 'shell',
            spec: parts.take(5).join(' '),
            status: true,
          ),
        );
      }
    }
    return result;
  }

  Future<void> _addTask() async {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController(text: '0 2 * * *');
    final scriptCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建计划任务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: specCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cron 表达式',
                  hintText: '分 时 日 月 周，如 0 2 * * *',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: scriptCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Shell 脚本',
                  border: OutlineInputBorder(),
                ),
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
    );
    if (saved != true) return;
    final name = nameCtrl.text.trim();
    final spec = specCtrl.text.trim();
    final script = scriptCtrl.text.trim();
    if (name.isEmpty || spec.isEmpty || script.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写完整')));
      return;
    }
    // API 优先
    try {
      await CronjobApi.createShell(name: name, spec: spec, script: script);
    } catch (e) {
      // SSH fallback：追加 crontab
      try {
        final ssh = ref.read(sshServiceProvider);
        if (ssh == null) throw e;
        await ssh.execute(
          '(crontab -l 2>/dev/null; echo "$spec /bin/sh -c \'$script\'") | crontab -',
        );
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('创建失败: $e')));
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务已创建')));
      _load();
    }
  }

  Future<void> _runNow(CronjobItem item) async {
    try {
      await CronjobApi.runOnce(item.name);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('执行失败: $e')));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已触发执行')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('计划任务')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: Icon(Icons.add),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text(_error!),
                  SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: Icon(Icons.refresh),
                    label: Text('重试'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(12),
                children: [
                  if (_usingSsh)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '（当前通过 SSH 读取系统 crontab）',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (_items.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(
                        child: Text(
                          '暂无计划任务，点击右下角 + 新建',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._items.map(
                      (item) => Card(
                        child: ListTile(
                          leading: Icon(
                            item.isRunning
                                ? Icons.schedule
                                : Icons.schedule_outlined,
                            color: item.isRunning
                                ? Colors.green
                                : theme.colorScheme.outline,
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.type} · ${item.spec}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'run') _runNow(item);
                              if (v == 'del') _delete(item.name);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'run',
                                child: Text('立即执行'),
                              ),
                              const PopupMenuItem(
                                value: 'del',
                                child: Text('删除'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _delete(String name) async {
    try {
      await CronjobApi.delete(name);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除')));
      _load();
    }
  }
}
