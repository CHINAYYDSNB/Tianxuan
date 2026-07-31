import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/server_service.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(serverServiceProvider);
      final mirrors = await svc.getRegistryMirrors();
      setState(() {
        _mirrors = mirrors;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final svc = ref.read(serverServiceProvider);
    try {
      await svc.updateRegistryMirrors(_mirrors);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('镜像源已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF686F78),
                            ),
                            SizedBox(width: 8),
                            Text('修改后需点右上角「保存」生效'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '配置由 1Panel 管理（/etc/docker/daemon.json）',
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
                  ..._mirrors.asMap().entries.map(
                    (e) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.cloud_outlined,
                          color: Colors.teal,
                        ),
                        title: Text(
                          e.value,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _mirrors.removeAt(e.key)),
                        ),
                      ),
                    ),
                  ),
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
