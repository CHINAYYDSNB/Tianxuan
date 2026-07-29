class ComposeItem {
  final String name;
  final String createdAt;
  final String createdBy;
  final int containerCount;
  final int runningCount;
  final String configFile;
  final String workdir;
  final bool composeFileExists;
  final String path;
  final List<ComposeContainer> containers;
  final String env;

  ComposeItem({
    required this.name,
    this.createdAt = '',
    this.createdBy = '',
    this.containerCount = 0,
    this.runningCount = 0,
    this.configFile = '',
    this.workdir = '',
    this.composeFileExists = false,
    this.path = '',
    this.containers = const [],
    this.env = '',
  });

  factory ComposeItem.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return ComposeItem(
      name: s(json['name']),
      createdAt: s(json['createdAt']),
      createdBy: s(json['createdBy']),
      containerCount: _toInt(json['containerCount']),
      runningCount: _toInt(json['runningCount']),
      configFile: s(json['configFile']),
      workdir: s(json['workdir']),
      composeFileExists: json['composeFileExists'] == true,
      path: s(json['path']),
      containers: json['containers'] is List
          ? (json['containers'] as List)
                .map(
                  (e) => ComposeContainer.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : [],
      env: s(json['env']),
    );
  }

  String get statusLabel {
    if (runningCount == containerCount && containerCount > 0) return '运行中';
    if (runningCount == 0 && containerCount > 0) return '已停止';
    if (containerCount == 0) return '空';
    return '部分运行';
  }

  bool get isRunning => runningCount > 0;
}

class ComposeContainer {
  final String containerID;
  final String name;
  final String createTime;
  final String state;
  final List<String>? ports;

  ComposeContainer({
    this.containerID = '',
    this.name = '',
    this.createTime = '',
    this.state = '',
    this.ports,
  });

  factory ComposeContainer.fromJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    return ComposeContainer(
      containerID: s(json['containerID']),
      name: s(json['name']),
      createTime: s(json['createTime']),
      state: s(json['state']),
      ports: json['ports'] is List
          ? (json['ports'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is num) return v.toInt();
  return 0;
}
