/// 任务日志读取结果（POST /files/read，type=task）。
class TaskLog {
  final bool end;
  final String path;
  final int total;
  final String taskStatus;
  final List<String> lines;
  final String scope;
  final int totalLines;

  const TaskLog({
    required this.end,
    this.path = '',
    this.total = 0,
    this.taskStatus = '',
    this.lines = const [],
    this.scope = '',
    this.totalLines = 0,
  });

  bool get isExecuting => taskStatus.toLowerCase() == 'executing';

  factory TaskLog.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List?;
    return TaskLog(
      end: json['end'] as bool? ?? true,
      path: json['path']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      taskStatus: json['taskStatus']?.toString() ?? '',
      lines:
          rawLines?.map((l) => l.toString()).toList(growable: false) ??
          const [],
      scope: json['scope']?.toString() ?? '',
      totalLines: (json['totalLines'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 慢日志文件读取结果（POST /files/read，type=mysql-slow-logs）。
class SlowLogFile {
  final bool end;
  final String path;
  final int total;
  final List<String> lines;
  final int totalLines;

  const SlowLogFile({
    required this.end,
    this.path = '',
    this.total = 0,
    this.lines = const [],
    this.totalLines = 0,
  });

  factory SlowLogFile.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List?;
    return SlowLogFile(
      end: json['end'] as bool? ?? true,
      path: json['path']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      lines:
          rawLines?.map((l) => l.toString()).toList(growable: false) ??
          const [],
      totalLines: (json['totalLines'] as num?)?.toInt() ?? 0,
    );
  }
}
