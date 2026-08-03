import '../models/server_status.dart';
import 'ssh_command_service.dart';

/// 通过 SSH 死命令采集服务器监控状态（纯 SSH，不走 1Panel API）。
class SshMonitor {
  final SshCommandService _ssh;

  SshMonitor(this._ssh);

  bool get isConnected => _ssh.isConnected;

  /// 一次性采集所有监控指标
  Future<ServerStatus> fetchStatus() async {
    // 并行执行多组命令
    final results = await Future.wait([
      _ssh.execute('top -bn1'),
      _ssh.execute('free -m'),
      _ssh.execute('df -h'),
      _ssh.execute('uptime'),
      _ssh.execute('hostname'),
      _ssh.execute('uname -s -r'),
      _ssh.execute('cat /proc/cpuinfo | grep "model name" | head -1'),
      _ssh.execute('cat /proc/cpuinfo | grep -c processor'),
      _ssh.execute("hostname -I | awk '{print \$1}'"),
    ]);

    final top = results[0].stdout;
    final free = results[1].stdout;
    final df = results[2].stdout;
    final uptimeRaw = results[3].stdout;
    final hostname = results[4].stdout.trim();
    final uname = results[5].stdout.trim();
    final cpuModel = results[6].stdout.trim();
    final coresRaw = results[7].stdout.trim();
    final ipRaw = results[8].stdout.trim();

    return ServerStatus(
      hostname: hostname.isEmpty ? ipRaw : hostname,
      platform: _parsePlatform(uname),
      kernelVersion: _parseKernel(uname),
      cpuModelName: _cleanCpuModel(cpuModel),
      cpuCores: int.tryParse(coresRaw) ?? 0,
      ipv4Address: ipRaw,
      cpuUsage: _parseCpu(top),
      memoryUsage: _parseMemUsedPercent(free),
      diskUsage: _parseDiskUsedPercent(df),
      uptime: _parseUptime(uptimeRaw),
      uptimeSeconds: _parseUptimeSeconds(uptimeRaw),
      memoryTotal: _parseMemTotal(free),
      memoryUsed: _parseMemUsed(free),
      diskTotal: _parseDiskTotal(df),
      diskUsed: _parseDiskUsed(df),
    );
  }

  // ─── CPU ───

  /// 解析 top -bn1 的 CPU 行: "%Cpu(s):  5.0 us, ..."
  double _parseCpu(String top) {
    final m = RegExp(r'%Cpu\(s?\):\s+([\d.]+)\s+us').firstMatch(top);
    if (m != null) {
      final us = double.tryParse(m.group(1)!) ?? 0;
      // us 是用户态占用，加系统态近似总占用
      final sys = RegExp(r'([\d.]+)\s+sy').firstMatch(top);
      final sy = sys != null ? double.tryParse(sys.group(1)!) ?? 0 : 0;
      return (us + sy).clamp(0, 100);
    }
    return 0;
  }

  // ─── 内存 ───

  String _parseMemTotal(String free) {
    final m = RegExp(r'Mem:\s+(\d+)').firstMatch(free);
    if (m == null) return '';
    final mb = int.tryParse(m.group(1)!) ?? 0;
    return _fmtMb(mb);
  }

  String _parseMemUsed(String free) {
    final m = RegExp(r'Mem:\s+\d+\s+(\d+)').firstMatch(free);
    if (m == null) return '';
    final mb = int.tryParse(m.group(1)!) ?? 0;
    return _fmtMb(mb);
  }

  double _parseMemUsedPercent(String free) {
    final total = RegExp(r'Mem:\s+(\d+)').firstMatch(free);
    final used = RegExp(r'Mem:\s+\d+\s+(\d+)').firstMatch(free);
    if (total == null || used == null) return 0;
    final t = double.tryParse(total.group(1)!) ?? 0;
    final u = double.tryParse(used.group(1)!) ?? 0;
    if (t <= 0) return 0;
    return (u / t * 100).clamp(0, 100);
  }

  // ─── 磁盘 ───

  /// 解析 df -h 根分区使用率（/ 挂载点）
  double _parseDiskUsedPercent(String df) {
    for (final line in df.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 6 && parts.last == '/') {
        final pct = parts[4].replaceAll('%', '');
        return (double.tryParse(pct) ?? 0).clamp(0, 100);
      }
    }
    return 0;
  }

  String _parseDiskTotal(String df) {
    for (final line in df.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 6 && parts.last == '/') return parts[1];
    }
    return '';
  }

  String _parseDiskUsed(String df) {
    for (final line in df.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 6 && parts.last == '/') return parts[2];
    }
    return '';
  }

  // ─── 运行时间 ───

  String _parseUptime(String raw) {
    // up 3 days, 4 hours, 5 minutes
    final m = RegExp(r'up\s+(.*?)(,\s*\d+ users)?').firstMatch(raw);
    return m != null ? m.group(1)!.trim() : raw.trim();
  }

  int _parseUptimeSeconds(String raw) {
    var total = 0;
    // days
    final d = RegExp(r'(\d+)\s+days?').firstMatch(raw);
    if (d != null) total += (int.tryParse(d.group(1)!) ?? 0) * 86400;
    // hours
    final h = RegExp(r'(\d+)\s+hours?').firstMatch(raw);
    if (h != null) total += (int.tryParse(h.group(1)!) ?? 0) * 3600;
    // minutes
    final m = RegExp(r'(\d+)\s+minutes?').firstMatch(raw);
    if (m != null) total += (int.tryParse(m.group(1)!) ?? 0) * 60;
    // seconds (up 5 minutes, up 42 sec)
    final s = RegExp(r'(\d+)\s+sec').firstMatch(raw);
    if (s != null) total += int.tryParse(s.group(1)!) ?? 0;
    // minutes shorthand "up 5 min"
    if (total == 0) {
      final mins = RegExp(r'(\d+)\s+min').firstMatch(raw);
      if (mins != null) total = (int.tryParse(mins.group(1)!) ?? 0) * 60;
    }
    return total;
  }

  // ─── 系统信息 ───

  String _parsePlatform(String uname) {
    // Linux hostname 6.1.0 #1 SMP ... x86_64 GNU/Linux
    final parts = uname.split(' ');
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0];
    return uname;
  }

  String _parseKernel(String uname) {
    final parts = uname.split(' ');
    if (parts.length >= 3) return parts[2];
    return uname;
  }

  String _cleanCpuModel(String raw) {
    final cleaned = raw.replaceAll('model name', '').replaceAll(':', '').trim();
    return cleaned;
  }

  String _fmtMb(int mb) {
    if (mb >= 1024 * 1024) {
      return '${(mb / 1024 / 1024).toStringAsFixed(1)} GB';
    }
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '$mb MB';
  }
}
