import 'dart:async';
import 'package:tianxuan/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/ssh_command_service.dart';
import '../settings/ssh_config_page.dart';

/// 服务器系统设置页 — 通过 SSH 直接执行命令（不走 1Panel API）。
/// 使用 ref.watch 监听 SSH 连接状态：未连接时立即显示引导，不转圈。
class ServerSystemPage extends ConsumerStatefulWidget {
  const ServerSystemPage({super.key});

  @override
  ConsumerState<ServerSystemPage> createState() => _ServerSystemPageState();
}

class _ServerSystemPageState extends ConsumerState<ServerSystemPage> {
  bool _loading = true;
  String? _error;

  // 当前值
  String _hostname = '';
  String _timezone = '';
  String _ntp = '';
  String _dns = '';
  String _swap = '';
  String _serverTime = '';
  List<String> _dnsList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'SSH 未连接';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // 分步读取，每条命令独立超时，任一失败不影响其余
    try {
      await Future.wait([
        _readHostname(ssh),
        _readTimezone(ssh),
        _readNtp(ssh),
        _readDns(ssh),
        _readSwap(ssh),
        _readServerTime(ssh),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _readHostname(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute('hostname 2>/dev/null || echo "-"')
          .timeout(const Duration(seconds: 8));
      _hostname = r.stdout.trim();
    } catch (_) {
      _hostname = '-';
    }
  }

  Future<void> _readTimezone(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute(
            'cat /etc/timezone 2>/dev/null || '
            'timeout 5 timedatectl show -p Timezone --value 2>/dev/null || echo "-"',
          )
          .timeout(const Duration(seconds: 8));
      _timezone = r.stdout.trim();
    } catch (_) {
      _timezone = '-';
    }
  }

  Future<void> _readNtp(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute(
            'timeout 5 timedatectl show-timesync -p FallbackNTPServers --value 2>/dev/null || echo "-"',
          )
          .timeout(const Duration(seconds: 8));
      _ntp = r.stdout.trim();
    } catch (_) {
      _ntp = '-';
    }
  }

  Future<void> _readDns(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute(
            "grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print \$2}' || echo '-'",
          )
          .timeout(const Duration(seconds: 8));
      _dns = r.stdout.trim();
      _dnsList = _dns
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty && e != '-')
          .toList();
    } catch (_) {
      _dns = '-';
      _dnsList = [];
    }
  }

  Future<void> _readSwap(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute('free -h 2>/dev/null | grep Swap || echo "-"')
          .timeout(const Duration(seconds: 8));
      _swap = r.stdout.trim();
    } catch (_) {
      _swap = '-';
    }
  }

  Future<void> _readServerTime(SshCommandService ssh) async {
    try {
      final r = await ssh
          .execute("date '+%Y-%m-%d %H:%M:%S' 2>/dev/null")
          .timeout(const Duration(seconds: 8));
      _serverTime = r.stdout.trim();
    } catch (_) {
      _serverTime = '-';
    }
  }

  Future<String?> _runSsh(String cmd) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return 'SSH 未连接';
    try {
      final res = await ssh.execute(cmd).timeout(const Duration(seconds: 15));
      if (!res.isSuccess) {
        return res.stderr.trim().isEmpty ? '命令执行失败' : res.stderr.trim();
      }
      return null;
    } catch (e) {
      return e is TimeoutException ? '命令执行超时' : '$e';
    }
  }

  void _showOk(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }

  Future<String?> _editDialog(
    String title,
    String label,
    String initial, {
    bool obscure = false,
    int lines = 1,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: obscure,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _editHostname() async {
    final v = await _editDialog(
      '修改主机名',
      '主机名',
      _hostname == '-' ? '' : _hostname,
    );
    if (v == null || v.isEmpty || v == _hostname) return;
    final err = await _runSsh(
      'sudo hostnamectl set-hostname "$v" 2>/dev/null || hostname "$v"',
    );
    if (!mounted) return;
    if (err != null) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('主机名已更新');
    _load();
  }

  Future<void> _editNtp() async {
    final v = await _editDialog(
      '修改 NTP 服务器',
      'NTP 地址',
      _ntp == '-' ? '' : _ntp,
    );
    if (v == null || v.isEmpty) return;
    final err = await _runSsh(
      'sudo timedatectl set-ntp true; '
      'echo -e "[Time]\\nNTP=$v" | sudo tee /etc/systemd/timesyncd.conf > /dev/null; '
      'sudo systemctl restart systemd-timesyncd 2>/dev/null || true',
    );
    if (!mounted) return;
    if (err != null) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('NTP 已更新');
    _load();
  }

  Future<void> _editDns() async {
    final current = _dnsList.join('\n');
    final v = await _editDialog('修改 DNS', '每行一个 nameserver', current, lines: 4);
    if (v == null || v.isEmpty) return;
    final lines = v.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty);
    final content = lines.map((e) => 'nameserver $e').join('\n');
    final err = await _runSsh(
      "echo -e '$content' | sudo tee /etc/resolv.conf > /dev/null",
    );
    if (!mounted) return;
    if (err != null) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('DNS 已更新');
    _load();
  }

  Future<void> _editPassword() async {
    final v = await _editDialog('修改系统密码', '新密码', '', obscure: true);
    if (v == null || v.isEmpty) return;
    final err = await _runSsh("echo 'root:$v' | sudo chpasswd");
    if (!mounted) return;
    if (err != null) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('系统密码已更新');
  }

  Future<void> _pickTimeZone() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    try {
      final res = await ssh
          .execute(
            'timedatectl list-timezones 2>/dev/null || '
            'cat /usr/share/zoneinfo/zone.tab 2>/dev/null | awk \'NF>=3 {print \$3}\' | head -200',
          )
          .timeout(const Duration(seconds: 10));
      final zones = res.stdout
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (!mounted || zones.isEmpty) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => ListView.builder(
          itemCount: zones.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(zones[i], style: const TextStyle(fontSize: 14)),
            onTap: () => Navigator.pop(ctx, zones[i]),
          ),
        ),
      );
      if (selected == null || selected == _timezone) return;
      final err = await _runSsh('sudo timedatectl set-timezone "$selected"');
      if (!mounted) return;
      if (err != null) {
        _showErr('修改失败: $err');
        return;
      }
      _showOk('时区已更新');
      _load();
    } catch (e) {
      if (mounted) _showErr(e);
    }
  }

  Future<void> _editSwap() async {
    final v = await _editDialog('修改 Swap 大小', '大小 GB（0 表示移除）', '2');
    if (v == null) return;
    final size = int.tryParse(v);
    if (size == null || size < 0) {
      _showErr('请输入合法的 GB 数值');
      return;
    }
    String? err;
    if (size == 0) {
      err = await _runSsh(
        'sudo swapoff -a 2>/dev/null; sudo rm -f /swapfile /swap.img 2>/dev/null; true',
      );
    } else {
      err = await _runSsh(
        'sudo swapoff -a 2>/dev/null; '
        'sudo fallocate -l ${size}G /swapfile && sudo chmod 600 /swapfile && '
        'sudo mkswap /swapfile > /dev/null && sudo swapon /swapfile && '
        'echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null; true',
      );
    }
    if (!mounted) return;
    if (err != null) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('Swap 已更新');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // 监听 SSH 连接：未连接直接显示引导，不转圈
    final ssh = ref.watch(sshServiceProvider);
    if (ssh == null) {
      return Scaffold(
        appBar: AppBar(title: Text('系统设置')),
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
                  '系统设置通过 SSH 读取服务器信息，请先配置 SSH 连接',
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
                    // 配置返回后若 SSH 已连接则重新加载
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
      appBar: AppBar(title: Text('系统设置')),
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
                    SizedBox(height: 12),
                    Text(_error!, style: TextStyle(fontSize: 14)),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  Card(
                    child: Column(
                      children: [
                        _row(
                          Icons.computer,
                          '主机名',
                          _hostname,
                          onTap: _editHostname,
                        ),
                        _row(Icons.watch_later_outlined, '服务器时间', _serverTime),
                        _row(
                          Icons.public,
                          '时区',
                          _timezone,
                          onTap: _pickTimeZone,
                        ),
                        _row(Icons.schedule, 'NTP 服务器', _ntp, onTap: _editNtp),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        _row(
                          Icons.dns_outlined,
                          'DNS',
                          _dnsList.isEmpty ? '-' : _dnsList.join(', '),
                          onTap: _editDns,
                        ),
                        _row(Icons.memory, 'Swap', _swap, onTap: _editSwap),
                        _row(
                          Icons.lock_outline,
                          '系统密码',
                          '••••••',
                          onTap: _editPassword,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '以上操作通过 SSH 直接执行，需要 root 权限',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, color: AppColors.iconFaint)
          : null,
      onTap: onTap,
    );
  }
}
