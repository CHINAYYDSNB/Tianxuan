import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/docker_service.dart';
import '../../services/docker_parser.dart';
import '../settings/ssh_config_page.dart';

class RegistryMirrorPage extends ConsumerStatefulWidget {
  const RegistryMirrorPage({super.key});

  @override
  ConsumerState<RegistryMirrorPage> createState() => _RegistryMirrorPageState();
}

class _RegistryMirrorPageState extends ConsumerState<RegistryMirrorPage> {
  List<String> _mirrors = [];
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
      final result = await svc.readDaemonJson();
      if (!result.isSuccess) {
        setState(() { _loading = false; _error = '读取失败: ${result.stderr}'; });
        return;
      }
      final mirrors = DockerParser.parseRegistryMirrors(result.stdout);
      setState(() {
        _mirrors = mirrors;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    final json = DockerParser.buildDaemonJson(_mirrors);
    final result = await svc.writeDaemonJson(json);
    if (!result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('写入失败: ${result.stderr}'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // Reload daemon
    final reloadResult = await svc.reloadDaemon();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reloadResult.isSuccess ? '配置已保存并重载 Docker' : '配置已保存，重载失败: ${reloadResult.stderr}'),
        ),
      );
    }
  }

  void _addMirror() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加镜像源'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://mirror.example.com',
            labelText: 'Mirror URL',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                setState(() => _mirrors.add(url));
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('镜像站'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(_error!, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        if (_error == 'SSH 未连接')
                          FilledButton.icon(
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SshConfigPage())),
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text('设置 SSH 连接'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFF686F78)),
                                const SizedBox(width: 8),
                                const Text('修改后需点右上角「保存」生效'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '配置文件: /etc/docker/daemon.json',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: const Color(0xFF686F78),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_mirrors.isEmpty)
                      const Center(child: Text('暂无镜像源'))
                    else
                      ..._mirrors.asMap().entries.map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.cloud_outlined, color: Colors.teal),
                              title: Text(e.value, style: const TextStyle(fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => setState(() => _mirrors.removeAt(e.key)),
                              ),
                            ),
                          )),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addMirror,
                      icon: const Icon(Icons.add),
                      label: const Text('添加镜像源'),
                    ),
                  ],
                ),
    );
  }
}
