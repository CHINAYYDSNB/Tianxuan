import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import 'desktop_server_provider.dart';
import '../../services/ssh_command_service.dart';
import '../../models/server_status.dart';

/// SSH 状态采集：连接一台服务器并拉取 CPU/内存/磁盘/uptime。
/// 纯 SSH 实现，不依赖 1Panel API。
class SshStatusCollector {
  SshCommandService? _ssh;

  Future<void> connect(DesktopServer server) async {
    if (_ssh?.isConnected == true) return;
    _ssh = SshCommandService();
    await _ssh!.connect(
      SshConfig(
        host: server.host,
        port: server.port,
        username: server.username,
        password: server.password,
        privateKey: server.privateKey,
      ),
    );
  }

  Future<ServerStatus?> collect() async {
    final ssh = _ssh;
    if (ssh == null || !ssh.isConnected) return null;
    try {
      final host = await ssh.execute('hostname 2>/dev/null');
      final cpu = await ssh.execute('top -bn1 | head -n 5 | tail -n 1');
      final mem = await ssh.execute(
        "free -m | awk '/^Mem/{print \$2\" \"\$3\" \"\$4}'",
      );
      final disk = await ssh.execute(
        "df -P / | awk 'NR==2{print \$2\" \"\$3\" \"\$5}'",
      );
      final uptime = await ssh.execute("awk '{print int(\$1)}' /proc/uptime");
      final plat = await ssh.execute(
        "head -n1 /etc/os-release | sed 's/NAME=\"//;s/\"//'",
      );

      final cpuPct = _parseCpuPercent(cpu.stdout).toDouble();
      final memParts = mem.stdout.trim().split(RegExp(r'\s+'));
      final diskParts = disk.stdout.trim().split(RegExp(r'\s+'));
      final totalMem = memParts.isNotEmpty
          ? double.tryParse(memParts[0]) ?? 0
          : 0;
      final usedMem = memParts.length > 1
          ? double.tryParse(memParts[1]) ?? 0
          : 0;
      final totalDisk = diskParts.isNotEmpty
          ? double.tryParse(diskParts[0]) ?? 0
          : 0;
      final usedDisk = diskParts.length > 1
          ? double.tryParse(diskParts[1]) ?? 0
          : 0;
      final memPct = (totalMem > 0 ? (usedMem / totalMem) * 100 : 0).toDouble();
      final diskPct = (totalDisk > 0 ? (usedDisk / totalDisk) * 100 : 0)
          .toDouble();
      final uptimeSec = int.tryParse(uptime.stdout.trim()) ?? 0;

      return ServerStatus(
        hostname: host.stdout.trim(),
        platform: plat.stdout.trim(),
        cpuUsage: cpuPct,
        memoryUsage: memPct,
        diskUsage: diskPct,
        uptime: '',
        uptimeSeconds: uptimeSec,
        memoryTotal: '${totalMem.toStringAsFixed(0)} MB',
        memoryUsed: '${usedMem.toStringAsFixed(0)} MB',
        diskTotal: _fmtBytes(totalDisk * 1024),
        diskUsed: _fmtBytes(usedDisk * 1024),
      );
    } catch (_) {
      return null;
    }
  }

  /// 解析 top 单行 load: "top - 14:22:00 up 1 day,  ...  1.2%wa, 0.5%si, 3.1%st"
  static double _parseCpuPercent(String line) {
    final idle = RegExp(r'(\d+(?:\.\d+)?)\s*%?id').firstMatch(line);
    if (idle == null) return 0;
    final v = double.tryParse(idle.group(1) ?? '') ?? 0;
    return (100 - v).clamp(0.0, 100.0).toDouble();
  }

  static String _fmtBytes(num bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
  }

  void dispose() {
    _ssh?.disconnect();
    _ssh = null;
  }
}

final sshStatusCollectorProvider = Provider.family<SshStatusCollector, String>((
  ref,
  serverId,
) {
  final collector = SshStatusCollector();
  ref.onDispose(collector.dispose);
  return collector;
});

/// 卡片实时状态流：连接 → 每 1s 采集一次
final desktopStatusProvider = StreamProvider.family<ServerStatus?, String>((
  ref,
  serverId,
) async* {
  final servers = ref
      .watch(desktopServersProvider)
      .where((s) => s.id == serverId)
      .toList();
  if (servers.isEmpty) {
    yield null;
    return;
  }
  final server = servers.first;
  final collector = ref.watch(sshStatusCollectorProvider(serverId));
  try {
    await collector.connect(server);
  } catch (e) {
    yield null;
    return;
  }
  while (true) {
    yield await collector.collect();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
  }
});
