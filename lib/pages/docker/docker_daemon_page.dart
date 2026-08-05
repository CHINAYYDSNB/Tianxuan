import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/docker_service.dart';
import '../../services/docker_parser.dart';
import '../settings/ssh_config_page.dart';

class DockerDaemonPage extends ConsumerStatefulWidget {
  const DockerDaemonPage({super.key});

  @override
  ConsumerState<DockerDaemonPage> createState() => _DockerDaemonPageState();
}

class _DockerDaemonPageState extends ConsumerState<DockerDaemonPage> {
  Map<String, dynamic>? _info;
  String _status = '';
  Map<String, dynamic>? _daemonJson;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  static const _logDrivers = ['json-file', 'journald', 'syslog', 'none'];
  static const _logSizes = ['none', '10m', '50m', '100m', '500m'];

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
      final ssh = ref.read(sshServiceProvider);
      if (ssh == null) {
        setState(() {
          _loading = false;
          _error = 'SSH 未连接';
        });
        return;
      }
      final svc = DockerService(ssh);

      final results = await Future.wait([
        svc.dockerInfo(),
        svc.daemonStatus(),
        svc.readDaemonJson(),
      ]);

      setState(() {
        _info = DockerParser.parseDockerInfo(results[0].stdout);
        _status = results[1].stdout;
        _daemonJson = _parseDaemonJson(results[2].stdout);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _parseDaemonJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '{}') return {};
    try {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      return {};
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

  // ─── daemon.json 配置操作 ───

  bool _boolValue(String key, {bool def = false}) {
    final v = _daemonJson?[key];
    return v is bool ? v : def;
  }

  void _toggleBool(String key, {bool def = false}) {
    setState(() => _daemonJson![key] = !_boolValue(key, def: def));
  }

  void _setLogDriver(String v) {
    setState(() {
      if (v == 'json-file') {
        _daemonJson!.remove('log-driver');
      } else {
        _daemonJson!['log-driver'] = v;
      }
    });
  }

  String _logSizeValue() {
    final opts = _daemonJson?['log-opts'];
    if (opts is Map) {
      final maxSize = opts['max-size']?.toString();
      if (maxSize != null) return maxSize;
    }
    return 'none';
  }

  void _setLogSize(String v) {
    setState(() {
      if (v == 'none') {
        final opts = _daemonJson!['log-opts'];
        if (opts is Map) {
          opts.remove('max-size');
          if (opts.isEmpty) _daemonJson!.remove('log-opts');
        }
      } else {
        final opts = _daemonJson!['log-opts'];
        if (opts is Map) {
          opts['max-size'] = v;
        } else {
          _daemonJson!['log-opts'] = {'max-size': v};
        }
      }
    });
  }

  List<String> _mirrors() {
    final m = _daemonJson?['registry-mirrors'];
    if (m is List) return m.map((e) => e.toString()).toList();
    return [];
  }

  Future<void> _addMirror() async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加镜像加速地址'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://docker.m.daocloud.io',
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
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    setState(() {
      final m = _daemonJson!['registry-mirrors'];
      if (m is List) {
        m.add(v);
      } else {
        _daemonJson!['registry-mirrors'] = [v];
      }
    });
  }

  void _removeMirror(int index) {
    setState(() {
      final m = _daemonJson!['registry-mirrors'];
      if (m is List) {
        m.removeAt(index);
        if (m.isEmpty) _daemonJson!.remove('registry-mirrors');
      }
    });
  }

  Future<void> _saveDaemon() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    setState(() => _saving = true);
    final content = jsonEncode(_daemonJson);
    try {
      final w = await svc.writeDaemonJson(content);
      if (!w.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: ${w.stderr}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final reload = await svc.reloadDaemon();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reload.isSuccess ? '配置已保存并生效' : '已保存，但重载失败: ${reload.stderr}',
          ),
          backgroundColor: reload.isSuccess ? Colors.green : Colors.orange,
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                    if (_error == 'SSH 未连接')
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SshConfigPage(),
                          ),
                        ),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statusCard(theme),
                  const SizedBox(height: 12),
                  _actionRow(),
                  const SizedBox(height: 16),
                  if (_info != null && _info!.isNotEmpty) ...[
                    _sectionTitle('Docker 信息'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _infoRow(
                              '版本',
                              _info!['ServerVersion']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '存储驱动',
                              _info!['Driver']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '容器数',
                              _info!['Containers']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '镜像数',
                              _info!['Images']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'Cgroup 驱动',
                              _info!['CgroupDriver']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'Docker Root',
                              _info!['DockerRootDir']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'OS',
                              _info!['OperatingSystem']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '日志驱动',
                              _info!['LoggingDriver']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'IPv4 转发',
                              _info!['IPv4Forwarding']?.toString() ?? '-',
                            ),
                            _infoRow(
                              'IPv6 转发',
                              _info!['IPv6Forwarding']?.toString() ?? '-',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_daemonJson != null) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('守护进程配置'),
                    const SizedBox(height: 8),
                    _configCard(theme),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveDaemon,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? '保存中...' : '保存配置并重载 Docker'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '修改 daemon.json 需要 root 权限，保存后将自动 systemctl reload docker',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9AA1A9)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _statusCard(ThemeData theme) {
    return Card(
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
    );
  }

  Widget _actionRow() {
    return Row(
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
    );
  }

  Widget _configCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.network_check),
            title: const Text('iptables'),
            subtitle: const Text('启用防火墙规则管理'),
            value: _boolValue('iptables', def: true),
            onChanged: (_) => _toggleBool('iptables', def: true),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: const Icon(Icons.language),
            title: const Text('IPv6'),
            subtitle: const Text('启用 IPv6 网络'),
            value: _boolValue('ipv6'),
            onChanged: (_) => _toggleBool('ipv6'),
          ),
          const Divider(height: 1, indent: 56),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: const Text('Live Restore'),
            subtitle: const Text('守护进程重启时保留容器运行'),
            value: _boolValue('live-restore'),
            onChanged: (_) => _toggleBool('live-restore'),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('日志驱动'),
            trailing: DropdownButton<String>(
              value: _logDrivers.contains(_daemonJson?['log-driver'])
                  ? _daemonJson!['log-driver'] as String
                  : 'json-file',
              underline: const SizedBox.shrink(),
              items: _logDrivers
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => v != null ? _setLogDriver(v) : null,
            ),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.cut_outlined),
            title: const Text('日志大小上限'),
            trailing: DropdownButton<String>(
              value: _logSizes.contains(_logSizeValue())
                  ? _logSizeValue()
                  : 'none',
              underline: const SizedBox.shrink(),
              items: _logSizes
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => v != null ? _setLogSize(v) : null,
            ),
          ),
          const Divider(height: 1, indent: 56),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync_outlined, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('镜像加速', style: TextStyle(fontSize: 16)),
                ),
                IconButton(
                  tooltip: '添加镜像加速',
                  icon: const Icon(Icons.add),
                  onPressed: _addMirror,
                ),
              ],
            ),
          ),
          if (_mirrors().isNotEmpty)
            ..._mirrors().asMap().entries.map(
              (e) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 56, right: 8),
                title: Text(
                  e.value,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeMirror(e.key),
                ),
              ),
            ),
        ],
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
