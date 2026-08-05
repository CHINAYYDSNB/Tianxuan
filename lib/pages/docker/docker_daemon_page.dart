import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/docker_service.dart';
import '../settings/ssh_config_page.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// Docker 设置页 — 移植自 Lanxi（仓库 / 基础配置 / 全部配置）
class DockerDaemonPage extends ConsumerStatefulWidget {
  const DockerDaemonPage({super.key});

  @override
  ConsumerState<DockerDaemonPage> createState() => _DockerDaemonPageState();
}

class _DockerDaemonPageState extends ConsumerState<DockerDaemonPage> {
  Map<String, dynamic> _cfg = {};
  bool _loading = true;
  String? _error;

  // Registry
  final _mirrorsCtrl = TextEditingController();
  final _insecureCtrl = TextEditingController();
  // Basic config
  bool _ipv6 = false;
  bool _iptables = true;
  bool _liveRestore = false;
  String _cgroupDriver = 'systemd';
  final _logMaxSize = TextEditingController(text: '10m');
  final _logMaxFile = TextEditingController(text: '3');
  String _socketPath = '/var/run/docker.sock';
  // Full config
  final _fullConfigCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      setState(() {
        _loading = false;
        _error = 'SSH 未连接';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = DockerService(ssh);
      final r = await svc.readDaemonJson().timeout(const Duration(seconds: 15));
      final cfg = jsonDecode(r.stdout) as Map<String, dynamic>;
      _cfg = cfg;
      // mirrors
      final mirrors = cfg['registry-mirrors'] as List<dynamic>?;
      _mirrorsCtrl.text = mirrors?.join('\n') ?? '';
      // insecure
      final insecure = cfg['insecure-registries'] as List<dynamic>?;
      _insecureCtrl.text = insecure?.join('\n') ?? '';
      // basic
      _ipv6 = cfg['ipv6'] == true;
      _iptables = cfg['iptables'] != false;
      _liveRestore = cfg['live-restore'] == true;
      final opts = cfg['exec-opts'] as List<dynamic>? ?? [];
      _cgroupDriver = opts
          .firstWhere(
            (o) => o.toString().startsWith('native.cgroupdriver='),
            orElse: () => 'native.cgroupdriver=systemd',
          )
          .toString()
          .replaceAll('native.cgroupdriver=', '');
      final logOpts = cfg['log-opts'] as Map<String, dynamic>?;
      _logMaxSize.text = logOpts?['max-size']?.toString() ?? '10m';
      _logMaxFile.text = logOpts?['max-file']?.toString() ?? '3';
      _socketPath = cfg['hosts'] != null
          ? (cfg['hosts'] as List).first.toString().replaceAll('unix://', '')
          : '/var/run/docker.sock';
      _fullConfigCtrl.text = const JsonEncoder.withIndent('  ').convert(cfg);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    // Merge with existing config to preserve custom fields
    final mirrors = _mirrorsCtrl.text
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final insecure = _insecureCtrl.text
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    _cfg['registry-mirrors'] = mirrors.isNotEmpty ? mirrors : null;
    _cfg['insecure-registries'] = insecure.isNotEmpty ? insecure : null;
    _cfg['ipv6'] = _ipv6;
    _cfg['iptables'] = _iptables;
    _cfg['live-restore'] = _liveRestore;
    _cfg['exec-opts'] = ['native.cgroupdriver=$_cgroupDriver'];
    _cfg['log-driver'] = 'json-file';
    _cfg['log-opts'] = {
      'max-size': _logMaxSize.text,
      'max-file': _logMaxFile.text,
    };
    // Remove null values
    _cfg.removeWhere((_, v) => v == null);
    final content = const JsonEncoder.withIndent('  ').convert(_cfg);
    final w = await svc
        .writeDaemonJson(content)
        .timeout(const Duration(seconds: 20));
    if (w.isSuccess) {
      await svc.reloadDaemon().timeout(const Duration(seconds: 20));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配置已保存并重载'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: ${w.stderr}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveFull() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final content = _fullConfigCtrl.text;
    try {
      jsonDecode(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 校验失败: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final svc = DockerService(ssh);
    final w = await svc
        .writeDaemonJson(content)
        .timeout(const Duration(seconds: 20));
    if (w.isSuccess) {
      await svc.reloadDaemon().timeout(const Duration(seconds: 20));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配置已保存并重载'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mirrorsCtrl.dispose();
    _insecureCtrl.dispose();
    _logMaxSize.dispose();
    _logMaxFile.dispose();
    _fullConfigCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ssh = ref.watch(sshServiceProvider);

    if (ssh == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Docker 设置')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal_outlined, size: 48, color: Colors.orange),
                SizedBox(height: 12),
                Text(
                  'SSH 未连接',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Docker 设置通过 SSH 读写 /etc/docker/daemon.json，请先配置 SSH',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SshConfigPage()),
                    );
                    _load();
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('去配置 SSH'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Docker 设置')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text(_error!, style: theme.textTheme.bodyMedium),
                    SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: Icon(Icons.refresh),
                      label: Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── 仓库 ──
                Text(
                  '仓库',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('镜像加速', style: _labelStyle(theme)),
                        SizedBox(height: 4),
                        TextField(
                          controller: _mirrorsCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: '每行一个 URL\nhttps://mirror.example.com',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text('私有仓库', style: _labelStyle(theme)),
                        SizedBox(height: 4),
                        TextField(
                          controller: _insecureCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: '每行一个地址\nregistry.example.com:5000',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14),
                // ── 基础配置 ──
                Text(
                  '基础配置',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('IPv6'),
                        value: _ipv6,
                        onChanged: (v) => setState(() => _ipv6 = v),
                        dense: true,
                      ),
                      SwitchListTile(
                        title: Text('iptables'),
                        subtitle: Text(
                          'Docker 自动配置 iptables 规则',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _iptables,
                        onChanged: (v) => setState(() => _iptables = v),
                        dense: true,
                      ),
                      SwitchListTile(
                        title: Text('Live restore'),
                        subtitle: Text(
                          'Docker 崩溃时保留容器运行状态',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _liveRestore,
                        onChanged: (v) => setState(() => _liveRestore = v),
                        dense: true,
                      ),
                      ListTile(
                        title: Text(
                          'Cgroup Driver',
                          style: TextStyle(fontSize: 14),
                        ),
                        trailing: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'systemd',
                              label: Text('systemd'),
                            ),
                            ButtonSegment(
                              value: 'cgroupfs',
                              label: Text('cgroupfs'),
                            ),
                          ],
                          selected: {_cgroupDriver},
                          onSelectionChanged: (s) =>
                              setState(() => _cgroupDriver = s.first),
                        ),
                        dense: true,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text('日志切割', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _logMaxSize,
                                decoration: InputDecoration(
                                  labelText: '大小',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: _logMaxFile,
                                decoration: InputDecoration(
                                  labelText: '数量',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        title: Text(
                          'Socket 路径',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _socketPath,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('保存基础配置并重载'),
                  ),
                ),
                const SizedBox(height: 20),
                // ── 全部配置 ──
                Text(
                  '全部配置',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: _fullConfigCtrl,
                      maxLines: 12,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _saveFull,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('保存全部配置并重载'),
                  ),
                ),
              ],
            ),
    );
  }

  TextStyle _labelStyle(ThemeData t) =>
      t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600) ??
      const TextStyle(fontWeight: FontWeight.w600);
}
