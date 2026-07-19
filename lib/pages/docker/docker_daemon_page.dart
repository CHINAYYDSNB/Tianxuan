import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/docker_service.dart';
import '../../services/docker_parser.dart';

class DockerDaemonPage extends ConsumerStatefulWidget {
  const DockerDaemonPage({super.key});

  @override
  ConsumerState<DockerDaemonPage> createState() => _DockerDaemonPageState();
}

class _DockerDaemonPageState extends ConsumerState<DockerDaemonPage> {
  Map<String, dynamic>? _info;
  String _status = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ssh = ref.read(sshServiceProvider);
      if (ssh == null) {
        setState(() { _loading = false; _error = 'SSH 未连接'; });
        return;
      }
      final svc = DockerService(ssh);

      // Load info and status in parallel
      final results = await Future.wait([
        svc.dockerInfo(),
        svc.daemonStatus(),
      ]);

      setState(() {
        _info = DockerParser.parseDockerInfo(results[0].stdout);
        _status = results[1].stdout;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
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
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    final result = await svc.daemonOp(op);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isSuccess ? '操作成功' : '操作失败: ${result.stderr}'),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
    _load();
  }

  bool get _isActive => _status.contains('Active: active');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Docker 管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Status card
                      Card(
                        color: _isActive
                            ? Colors.green.withValues(alpha: 0.08)
                            : Colors.red.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _isActive ? Icons.check_circle : Icons.error,
                                color: _isActive ? Colors.green : Colors.red,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isActive ? 'Docker 运行中' : 'Docker 已停止',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _status.split('\n').first,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: const Color(0xFF686F78),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isActive ? null : () => _daemonOp('start'),
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text('启动'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isActive ? () => _daemonOp('stop') : null,
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('停止'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isActive ? () => _daemonOp('restart') : null,
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text('重启'),
                              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Docker Info
                      if (_info != null && _info!.isNotEmpty) ...[
                        Text('Docker 信息',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _infoRow('版本', _info!['ServerVersion']?.toString() ?? '-'),
                                _infoRow('存储驱动', _info!['Driver']?.toString() ?? '-'),
                                _infoRow('容器数', _info!['Containers']?.toString() ?? '-'),
                                _infoRow('镜像数', _info!['Images']?.toString() ?? '-'),
                                _infoRow('Cgroup 驱动', _info!['CgroupDriver']?.toString() ?? '-'),
                                _infoRow('Docker Root', _info!['DockerRootDir']?.toString() ?? '-'),
                                _infoRow('OS', _info!['OperatingSystem']?.toString() ?? '-'),
                                _infoRow('Architecture', _info!['Architecture']?.toString() ?? '-'),
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
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF686F78))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
