class ServerStatus {
  // 服务器信息
  final String hostname;
  final String platform;
  final String kernelVersion;
  final String cpuModelName;
  final int cpuCores;
  final String ipv4Address;

  // 资源使用
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final String uptime;
  final int uptimeSeconds;
  final String memoryTotal;
  final String memoryUsed;
  final String diskTotal;
  final String diskUsed;

  ServerStatus({
    this.hostname = '',
    this.platform = '',
    this.kernelVersion = '',
    this.cpuModelName = '',
    this.cpuCores = 0,
    this.ipv4Address = '',
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.uptime,
    this.uptimeSeconds = 0,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.diskTotal,
    required this.diskUsed,
  });

  /// 人类可读的运行时长
  String get formattedUptime {
    if (uptimeSeconds <= 0) return uptime;
    final days = uptimeSeconds ~/ 86400;
    final hours = (uptimeSeconds % 86400) ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}天');
    if (hours > 0) parts.add('${hours}小时');
    if (minutes > 0) parts.add('${minutes}分');
    return parts.isEmpty ? '${uptimeSeconds}秒' : parts.join(' ');
  }

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    // 兼容 /dashboard/current (flat) 和 /dashboard/base (nested in currentInfo)
    final info = (json['currentInfo'] as Map<String, dynamic>?) ?? json;

    double parse(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0;
      return 0;
    }

    String fmt(dynamic val) {
      if (val == null) return '';
      if (val is String) return val;
      if (val is num) {
        // 字节 → 可读格式
        const units = ['B', 'KB', 'MB', 'GB', 'TB'];
        int i = 0;
        double v = val.toDouble();
        while (v >= 1024 && i < units.length - 1) {
          v /= 1024;
          i++;
        }
        return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
      }
      return val.toString();
    }

    // diskData 是数组，取第一个（根分区）
    final diskData = info['diskData'] as List<dynamic>? ?? [];
    final disk0 = diskData.isNotEmpty
        ? (diskData[0] as Map<String, dynamic>? ?? {})
        : <String, dynamic>{};

    return ServerStatus(
      hostname: json['hostname']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      kernelVersion: json['kernelVersion']?.toString() ?? '',
      cpuModelName: json['cpuModelName']?.toString() ?? '',
      cpuCores: (json['cpuCores'] as num?)?.toInt() ?? 0,
      ipv4Address: json['ipv4Address']?.toString() ?? '',
      cpuUsage: parse(info['cpuUsedPercent']),
      memoryUsage: parse(info['memoryUsedPercent']),
      diskUsage: parse(disk0['usedPercent']),
      uptime:
          info['timeSinceUptime']?.toString() ??
          info['uptime']?.toString() ??
          '',
      uptimeSeconds: (info['uptime'] is num)
          ? (info['uptime'] as num).toInt()
          : 0,
      memoryTotal: fmt(info['memoryTotal']),
      memoryUsed: fmt(info['memoryUsed']),
      diskTotal: fmt(disk0['total']),
      diskUsed: fmt(disk0['used']),
    );
  }
}
