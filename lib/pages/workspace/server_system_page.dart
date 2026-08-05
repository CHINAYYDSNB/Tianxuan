import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../services/ssh_command_service.dart';

/// 服务器系统设置页 — 全部通过 SSH 直接执行命令（不走 1Panel API）
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) {
      setState(() {
        _loading = false;
        _error = 'SSH 未连接';
      });
      return;
    }
    try {
      // 聚合读取系统信息（单次往返），每条命令 shell 层加 timeout 5 防挂起
      final cmd = [
        "hostname 2>/dev/null || echo '-'",
        "cat /etc/timezone 2>/dev/null || timeout 5 timedatectl show -p Timezone --value 2>/dev/null || echo '-'",
        "timeout 5 timedatectl show-timesync -p FallbackNTPServers --value 2>/dev/null || echo '-'",
        "grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print \$2}' || echo '-'",
        "free -h 2>/dev/null | grep Swap || echo '-'",
        "date '+%Y-%m-%d %H:%M:%S'",
      ].join("; echo '\$__SEP__'; ");
      final res = await ssh
          .execute(cmd)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              return const SshResult(exitCode: -1, stderr: '读取超时');
            },
          );
      final parts = res.stdout.split('\$__SEP__');
      if (!mounted) return;
      setState(() {
        _hostname = parts.length > 0 ? parts[0].trim() : '-';
        _timezone = parts.length > 1 ? parts[1].trim() : '-';
        _ntp = parts.length > 2 ? parts[2].trim() : '-';
        _dns = parts.length > 3 ? parts[3].trim() : '-';
        _swap = parts.length > 4 ? parts[4].trim() : '-';
        _serverTime = parts.length > 5 ? parts[5].trim() : '-';
        _dnsList = _dns
            .split(RegExp(r'\s+'))
            .where((e) => e.isNotEmpty && e != '-')
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<String?> _runSsh(String cmd) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return 'SSH 未连接';
    final res = await ssh.execute(cmd);
    if (!res.isSuccess)
      return res.stderr.trim().isEmpty ? '命令执行失败' : res.stderr.trim();
    return null;
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
    // 通过 timedatectl 启用时间同步；具体 NTP 服务器写入 timesyncd 配置
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
    // root 用户使用 chpasswd
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
      final res = await ssh.execute(
        'timedatectl list-timezones 2>/dev/null || cat /usr/share/zoneinfo/zone.tab 2>/dev/null | awk \'NF>=3 {print \$3}\' | head -200',
      );
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
    String err;
    if (size == 0) {
      err =
          await _runSsh(
            'sudo swapoff -a 2>/dev/null; sudo rm -f /swapfile /swap.img 2>/dev/null; true',
          ) ??
          '';
    } else {
      err =
          await _runSsh(
            'sudo swapoff -a 2>/dev/null; '
            'sudo fallocate -l ${size}G /swapfile && sudo chmod 600 /swapfile && '
            'sudo mkswap /swapfile > /dev/null && sudo swapon /swapfile && '
            'echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null; true',
          ) ??
          '';
    }
    if (!mounted) return;
    if (err.isNotEmpty) {
      _showErr('修改失败: $err');
      return;
    }
    _showOk('Swap 已更新');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_error!),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  const Text(
                    '以上操作通过 SSH 直接执行，需要 root 权限',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9AA1A9)),
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
          ? const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF))
          : null,
      onTap: onTap,
    );
  }
}
