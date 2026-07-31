import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/server_service.dart';

class DockerDaemonPage extends ConsumerStatefulWidget {
  const DockerDaemonPage({super.key});

  @override
  ConsumerState<DockerDaemonPage> createState() => _DockerDaemonPageState();
}

class _DockerDaemonPageState extends ConsumerState<DockerDaemonPage> {
  Map<String, dynamic>? _info;
  bool _loading = true;
  String? _error;

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
    try {
      final svc = ref.read(serverServiceProvider);
      final info = await svc.dockerInfo();
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<bool> _confirmOp(String op) async {
    final labels = {'start': '启动', 'stop': '停止', 'restart': '重启'};
    final label = labels[op] ?? op;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label Docker 守护进程'),
        content: Text('确定要${label} Docker 服务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定$label'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _daemonOp(String op) async {
    final confirmed = await _confirmOp(op);
    if (!confirmed) return;
    final svc = ref.read(serverServiceProvider);
    try {
      await svc.daemonOp(op);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Docker 管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!, style: theme.textTheme.bodyMedium),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.green.withValues(alpha: 0.08),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Docker 由 1Panel 管理',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _daemonOp('start'),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('启动'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _daemonOp('stop'),
                          icon: const Icon(Icons.stop, size: 18),
                          label: const Text('停止'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _daemonOp('restart'),
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('重启'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_info != null && _info!.isNotEmpty) ...[
                    Text(
                      'Docker 信息',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _infoRow(
                              '版本',
                              _info!['version']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '运行状态',
                              (_info!['isActive'] == true ? '运行中' : '已停止'),
                            ),
                            _infoRow(
                              'Cgroup 驱动',
                              _info!['cgroupDriver']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'Swarm',
                              (_info!['isSwarm'] == true ? '是' : '否'),
                            ),
                            _infoRow(
                              '实时恢复',
                              (_info!['liveRestore'] == true ? '开启' : '关闭'),
                            ),
                            _infoRow(
                              '日志大小上限',
                              _info!['logMaxSize']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '日志文件数',
                              _info!['logMaxFile']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '镜像加速源',
                              (_info!['registryMirrors'] is List &&
                                      (_info!['registryMirrors'] as List)
                                          .isNotEmpty)
                                  ? (_info!['registryMirrors'] as List)
                                        .map((e) => e.toString())
                                        .join(', ')
                                  : '无',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF686F78)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
