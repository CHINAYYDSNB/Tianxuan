/// 备份记录（对齐 Mono-Dash BackupRecordDto）。
class BackupRecord {
  final int id;
  final DateTime? createdAt;
  final String accountType;
  final String accountName;
  final int downloadAccountID;
  final String fileDir;
  final String fileName;
  final String taskID;
  final String status;
  final String message;
  final String description;
  final int size;

  const BackupRecord({
    required this.id,
    this.createdAt,
    this.accountType = '',
    this.accountName = '',
    this.downloadAccountID = 0,
    this.fileDir = '',
    this.fileName = '',
    this.taskID = '',
    this.status = '',
    this.message = '',
    this.description = '',
    this.size = 0,
  });

  String get filePath {
    final dir = fileDir.replaceAll(RegExp(r'/+$'), '');
    if (dir.isEmpty) return fileName;
    return '$dir/$fileName';
  }

  bool get isSuccess => status.toLowerCase() == 'success';

  BackupRecord copyWith({int? size}) {
    return BackupRecord(
      id: id,
      createdAt: createdAt,
      accountType: accountType,
      accountName: accountName,
      downloadAccountID: downloadAccountID,
      fileDir: fileDir,
      fileName: fileName,
      taskID: taskID,
      status: status,
      message: message,
      description: description,
      size: size ?? this.size,
    );
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    return BackupRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      accountType: json['accountType']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      downloadAccountID: (json['downloadAccountID'] as num?)?.toInt() ?? 0,
      fileDir: json['fileDir']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      taskID: json['taskID']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      size: 0,
    );
  }
}

/// 备份记录大小（异步补全）。
class BackupRecordSize {
  final int id;
  final int size;

  const BackupRecordSize({required this.id, required this.size});

  factory BackupRecordSize.fromJson(Map<String, dynamic> json) {
    return BackupRecordSize(
      id: (json['id'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 备份记录搜索请求。
class BackupRecordSearchReq {
  final int page;
  final int pageSize;
  final String type;
  final String name;
  final String detailName;

  const BackupRecordSearchReq({
    required this.page,
    required this.pageSize,
    required this.type,
    required this.name,
    required this.detailName,
  });

  Map<String, dynamic> toJson() => {
    'page': page,
    'pageSize': pageSize,
    'type': type,
    'name': name,
    'detailName': detailName,
  };
}

/// 备份账号选项（GET /backups/options）。
class BackupOption {
  final String type;
  final String name;
  final int id;

  const BackupOption({required this.type, this.name = '', this.id = 0});

  factory BackupOption.fromJson(Map<String, dynamic> json) {
    return BackupOption(
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}
