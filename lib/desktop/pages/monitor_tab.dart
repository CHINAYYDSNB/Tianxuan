import 'dart:async';
import 'package:flutter/material.dart';
import '../models/desktop_server.dart';
import '../../services/ssh_command_service.dart';
import '../../theme/app_colors.dart';

/// 实时监控标签页：SSH 拉取 CPU/内存/磁盘，每 1s 更新环形/进度指示。
class MonitorTab extends StatefulWidget {
  final DesktopServer server;
  const MonitorTab({super.key, required this.server});

  @override
  State<MonitorTab> createState() => _MonitorTabState();
}

class _MonitorTabState extends State<MonitorTab> {
  SshCommandService? _ssh;
  Timer? _timer;
  double _cpu = 0;
  double _mem = 0;
  double _disk = 0;
  String _hostname = '';
  String _os = '';
  int _uptime = 0;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final ssh = SshCommandService();
      await ssh.connect(
        SshConfig(
          host: widget.server.host,
          port: widget.server.port,
          username: widget.server.username,
          password: widget.server.password,
          privateKey: widget.server.privateKey,
        ),
      );
      _ssh = ssh;
      setState(() => _connecting = false);
      _poll();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _poll() async {
    final ssh = _ssh;
    if (ssh == null) return;
    final host = await ssh.execute('hostname 2>/dev/null');
    final os = await ssh.execute(
      "head -n1 /etc/os-release | sed 's/NAME=\"//;s/\"//'",
    );
    final cpu = await ssh.execute('top -bn1 | head -n 5 | tail -n 1');
    final mem = await ssh.execute("free -m | awk '/^Mem/{print \$2\" \"\$3}'");
    final disk = await ssh.execute(
      "df -P / | awk 'NR==2{print \$2\" \"\$3\" \"\$5}'",
    );
    final uptime = await ssh.execute("awk '{print int(\$1)}' /proc/uptime");
    if (!mounted) return;
    setState(() {
      _hostname = host.stdout.trim();
      _os = os.stdout.trim();
      _cpu = _parseCpu(cpu.stdout);
      final mp = mem.stdout.trim().split(RegExp(r'\s+'));
      if (mp.length >= 2) {
        final t = double.tryParse(mp[0]) ?? 0;
        final u = double.tryParse(mp[1]) ?? 0;
        _mem = t > 0 ? (u / t) * 100 : 0;
      }
      final dp = disk.stdout.trim().split(RegExp(r'\s+'));
      if (dp.isNotEmpty) {
        _disk = double.tryParse(dp[2].replaceAll('%', '')) ?? 0;
      }
      _uptime = int.tryParse(uptime.stdout.trim()) ?? 0;
    });
  }

  double _parseCpu(String line) {
    final idle = RegExp(r'(\d+(?:\.\d+)?)\s*%?id').firstMatch(line);
    if (idle == null) return 0;
    final v = double.tryParse(idle.group(1) ?? '') ?? 0;
    return (100 - v).clamp(0.0, 100.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ssh?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _start, child: const Text('重试')),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_hostname.isEmpty ? widget.server.host : _hostname} · $_os',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '运行时长 ${_fmtUptime(_uptime)}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _metricCard('CPU', _cpu)),
              const SizedBox(width: 16),
              Expanded(child: _metricCard('内存', _mem)),
              const SizedBox(width: 16),
              Expanded(child: _metricCard('磁盘', _disk)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, double value) {
    final color = value > 85
        ? Colors.red
        : value > 65
        ? Colors.orange
        : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (value / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                  Center(
                    child: Text(
                      '${value.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }

  String _fmtUptime(int seconds) {
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return '$d天 $h小时';
    if (h > 0) return '$h小时 $m分';
    return '$m分';
  }
}
