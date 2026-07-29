class FileItem {
  final String name;
  final String path;
  final String? extension;
  final bool isDir;
  final bool isHidden;
  final bool isSymlink;
  final int size;
  final String? modTime;
  final String? updateTime;
  final String? mode;
  final String? uid;
  final String? gid;
  final String? user;
  final String? group;
  final String? mimeType;
  final String? type;
  final String? content;
  final String? linkPath;
  final int? favoriteID;
  final int? itemTotal;
  final List<FileItem>? items;

  FileItem({
    required this.name,
    required this.path,
    this.extension,
    required this.isDir,
    this.isHidden = false,
    this.isSymlink = false,
    this.size = 0,
    this.modTime,
    this.updateTime,
    this.mode,
    this.uid,
    this.gid,
    this.user,
    this.group,
    this.mimeType,
    this.type,
    this.content,
    this.linkPath,
    this.favoriteID,
    this.itemTotal,
    this.items,
  });

  /// 人类可读大小
  String get formattedSize {
    if (isDir) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double v = size.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return i == 0 ? '${size} B' : '${v.toStringAsFixed(1)} ${units[i]}';
  }

  /// 权限字符串 (如 rwxr-xr-x)
  String get formattedMode {
    if (mode == null || mode!.isEmpty) return '';
    // mode 可能是 "0755" 形式
    if (mode!.startsWith('0') && mode!.length == 4) {
      return _modeToStr(int.tryParse(mode!, radix: 8) ?? 0);
    }
    return mode!;
  }

  static String _modeToStr(int octal) {
    const rwx = ['---', '--x', '-w-', '-wx', 'r--', 'r-x', 'rw-', 'rwx'];
    return '${rwx[(octal >> 6) & 7]}${rwx[(octal >> 3) & 7]}${rwx[octal & 7]}';
  }

  factory FileItem.fromJson(Map<String, dynamic> json) {
    String safeStr(dynamic v) => v?.toString() ?? '';
    int safeInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    List<FileItem>? parseItems(dynamic v) {
      if (v is! List) return null;
      return v
          .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return FileItem(
      name: safeStr(json['name']),
      path: safeStr(json['path']),
      extension: json['extension']?.toString(),
      isDir: json['isDir'] == true,
      isHidden: json['isHidden'] == true,
      isSymlink: json['isSymlink'] == true,
      size: safeInt(json['size']),
      modTime: json['modTime']?.toString(),
      updateTime: json['updateTime']?.toString(),
      mode: json['mode']?.toString(),
      uid: json['uid']?.toString(),
      gid: json['gid']?.toString(),
      user: json['user']?.toString(),
      group: json['group']?.toString(),
      mimeType: json['mimeType']?.toString(),
      type: json['type']?.toString(),
      content: json['content']?.toString(),
      linkPath: json['linkPath']?.toString(),
      favoriteID: safeInt(json['favoriteID']),
      itemTotal: safeInt(json['itemTotal']),
      items: parseItems(json['items']),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'extension': extension,
    'isDir': isDir,
    'isHidden': isHidden,
    'isSymlink': isSymlink,
    'size': size,
  };
}
