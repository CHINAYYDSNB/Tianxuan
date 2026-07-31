/// SSH-backed 系统信息采集，复制自 Lanxi 的 [SshServerSource] 解析逻辑。
///
/// 通过 [SshCommandService] 在远端执行 `top -bn1` / `free -m` / `df -Pk` 等命令，
/// 解析出 CPU / 内存 / 磁盘 / 负载 / 主机元信息，组装成 [ServerStatus]。
///
/// 与 1Panel 的 `/dashboard/base` 监控接口不同，此实现只依赖 SSH，不依赖任何
/// 面板接口，因此对任意可通过 SSH 登录的服务器都适用（移动端直连 dartssh2，
/// 网页端走 WsSSH 代理）。
library;

import 'dart:async';
import '../../models/server_status.dart';
import '../../services/ssh_command_service.dart';

class SshServerSource {
  final SshCommandService _cmd;

  const SshServerSource(this._cmd);

  static const _diskDelim = '__LANXI_DISK__';
  static const _metaDelim = '__LANXI_META__';

  /// 单次采集。info + disk + meta 合并为一条命令，减少 SSH 往返。
  Future<ServerStatus> getSystemInfo() async {
    final raw = await _cmd.execute(
      "top -bn1 | head -5; free -m; echo '$_diskDelim'; df -Pk; echo "
      "'$_metaDelim'; hostname; uname -r; uname -m; hostname -I; "
      "head -1 /proc/uptime; ( . /etc/os-release 2>/dev/null; "
      "printf 'PRETTY=%s\\n' \"\$PRETTY_NAME\" )",
    );
    if (!raw.isSuccess) {
      throw Exception('获取系统信息失败: ${raw.stderr}');
    }
    return _parse(raw.stdout);
  }

  ServerStatus _parse(String raw) {
    final diskIdx = raw.indexOf(_diskDelim);
    final metaIdx = raw.indexOf(_metaDelim);

    final infoRaw = diskIdx < 0 ? raw : raw.substring(0, diskIdx);
    final diskRaw = (diskIdx >= 0 && metaIdx >= 0)
        ? raw.substring(diskIdx + _diskDelim.length, metaIdx)
        : (diskIdx >= 0 ? raw.substring(diskIdx + _diskDelim.length) : '');
    final metaRaw = metaIdx >= 0
        ? raw.substring(metaIdx + _metaDelim.length)
        : '';

    // ── CPU / 内存（top + free）──
    double cpu = 0.0;
    int memTotalMb = 0;
    int memUsedMb = 0;
    for (final line in infoRaw.split('\n')) {
      final cpuMatch = RegExp(r'%Cpu\(s\):\s+(\d+\.?\d*)').firstMatch(line);
      if (cpuMatch != null) cpu = double.parse(cpuMatch[1]!);

      final memMatch = RegExp(
        r'(?:Mem|MiB Mem)[\s:]+(\d+\.?\d*)\s+(\d+\.?\d*)',
      ).firstMatch(line);
      if (memMatch != null) {
        memTotalMb = double.parse(memMatch[1]!).round();
        memUsedMb = double.parse(memMatch[2]!).round();
      }
    }

    // ── 磁盘（df -Pk）── 优先根分区，其次第一个真实磁盘。
    double diskUsage = 0.0;
    int diskTotalMb = 0;
    int diskUsedMb = 0;
    bool rootFound = false;
    for (final line in diskRaw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('Filesystem')) continue;
      final p = t.split(RegExp(r'\s+'));
      if (p.length < 6) continue;
      if (_isPseudoFs(p[0])) continue;

      final blocks = int.tryParse(p[1]) ?? 0;
      final used = int.tryParse(p[2]) ?? 0;
      final cap = int.tryParse(p[4].replaceAll('%', '')) ?? 0;
      final mount = p[5];

      if (mount == '/') {
        rootFound = true;
        diskUsage = cap.toDouble();
        diskTotalMb = (blocks / 1024).round();
        diskUsedMb = (used / 1024).round();
      } else if (!rootFound) {
        diskUsage = cap.toDouble();
        diskTotalMb = (blocks / 1024).round();
        diskUsedMb = (used / 1024).round();
      }
    }

    // ── 主机元信息 ──
    final meta = metaRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    String hostname = '';
    String kernel = '';
    String arch = '';
    String ip = '';
    String platform = '';
    int uptimeSeconds = 0;

    if (meta.isNotEmpty) hostname = meta[0];
    if (meta.length > 1) kernel = meta[1];
    if (meta.length > 2) arch = meta[2];
    if (meta.length > 3) {
      ip = meta[3].split(RegExp(r'\s+')).first;
    }
    if (meta.length > 4) {
      uptimeSeconds =
          (double.tryParse(meta[4].split(RegExp(r'\s+')).first) ?? 0).round();
    }
    if (meta.length > 5) {
      final pretty = meta[5];
      if (pretty.startsWith('PRETTY=')) platform = pretty.substring(7);
    }

    final memPct = memTotalMb > 0 ? (memUsedMb / memTotalMb * 100) : 0.0;

    return ServerStatus(
      hostname: hostname,
      platform: platform,
      kernelVersion: kernel,
      cpuModelName: arch,
      ipv4Address: ip,
      cpuUsage: cpu,
      memoryUsage: memPct,
      diskUsage: diskUsage,
      uptimeSeconds: uptimeSeconds,
      uptime: _fmtDuration(uptimeSeconds),
      memoryTotal: _fmtMb(memTotalMb),
      memoryUsed: _fmtMb(memUsedMb),
      diskTotal: _fmtMb(diskTotalMb),
      diskUsed: _fmtMb(diskUsedMb),
    );
  }

  /// 跳过伪文件系统（tmpfs / proc / cgroup …），但保留 overlay 等真实根盘。
  bool _isPseudoFs(String fs) {
    const pseudo = {
      'tmpfs',
      'devtmpfs',
      'proc',
      'sysfs',
      'cgroup',
      'cgroup2',
      'devpts',
      'mqueue',
      'autofs',
      'udev',
      'debugfs',
      'tracefs',
      'securityfs',
      'hugetlbfs',
      'binfmt_misc',
      'configfs',
      'efivarfs',
      'fusectl',
      'pstore',
      'rpc_pipefs',
      'nsfs',
      'ramfs',
    };
    return pseudo.contains(fs);
  }

  static String _fmtMb(int mb) {
    if (mb <= 0) return '0 MB';
    const units = ['MB', 'GB', 'TB'];
    double v = mb.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
  }

  static String _fmtDuration(int s) {
    if (s <= 0) return '';
    final days = s ~/ 86400;
    final hours = (s % 86400) ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final parts = <String>[];
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours小时');
    if (minutes > 0) parts.add('$minutes分');
    return parts.isEmpty ? '$s秒' : parts.join(' ');
  }
}
