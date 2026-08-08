import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../models/file_item.dart';
import 'client.dart';

/// 文件读取失败（区别于通用网络异常），便于 UI 给出明确提示而非 Dio 的
/// "接口不存在" 之类的泛化信息。
class FileReadException implements Exception {
  final String message;
  final int? statusCode;

  const FileReadException(this.message, [this.statusCode]);

  @override
  String toString() => statusCode != null
      ? 'FileReadException($statusCode): $message'
      : 'FileReadException: $message';
}

class FileApi {
  /// List files in directory
  /// POST /files/search
  static Future<FileListResult> getList({
    required String path,
    int page = 1,
    int pageSize = 50,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? showHidden,
    bool? isDetail,
  }) async {
    final data = <String, dynamic>{
      'path': path,
      'page': page,
      'pageSize': pageSize,
      'expand': true, // 不传 expand 不会返回 items
    };
    if (search != null) data['search'] = search;
    if (sortBy != null) data['sortBy'] = sortBy;
    if (sortOrder != null) data['sortOrder'] = sortOrder;
    if (showHidden == true) data['showHidden'] = true;
    if (isDetail == true) data['isDetail'] = true;

    final res = await ApiClient.instance.post('/files/search', data: data);
    final body = _parseBody(res);

    // Response.FileInfo — items 在 data.items 中
    final items = _parseItems(body['items']);
    final total = (body['itemTotal'] as num?)?.toInt() ?? items.length;
    return FileListResult(items: items, total: total);
  }

  /// Load file content
  /// POST /files/content  (ApiClient 自动补全为 /api/v2/files/content)
  /// 1Panel v2 返回明文 content（非 base64），原样返回。
  static Future<FileItem> getContent(String path) async {
    try {
      final res = await ApiClient.instance.post(
        '/files/content',
        data: {'path': path},
      );
      final body = _parseBody(res);
      return FileItem.fromJson(body);
    } on FileReadException {
      rethrow;
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Preview file content
  /// POST /files/preview
  static Future<FileItem> preview(String path) async {
    final res = await ApiClient.instance.post(
      '/files/preview',
      data: {'path': path},
    );
    final body = _parseBody(res);
    return FileItem.fromJson(body);
  }

  /// Read file content (1Panel v2 只有 /files/content 端点，没有独立的 read 端点)。
  /// 以整文件明文返回，按行切分；一次性返回 end=true，供编辑器/日志的分页循环终止。
  /// POST /files/content
  static Future<FileLineResult> readByLine(
    String path, {
    int page = 1,
    int pageSize = 100,
    String type = 'text',
  }) async {
    try {
      final res = await ApiClient.instance.post(
        '/files/content',
        data: {'path': path},
      );
      final body = _parseBody(res);
      final raw = body['content'];
      final src = raw is String ? raw : '';
      final text = src.replaceAll('\r\n', '\n');
      var lines = text.isEmpty ? <String>[] : text.split('\n');
      // 去掉因末尾换行产生的空尾行，避免编辑器多出一个空行
      if (lines.length > 1 && lines.last.isEmpty) {
        lines = lines.sublist(0, lines.length - 1);
      }
      return FileLineResult(
        lines: lines,
        total: lines.length,
        totalLines: lines.length,
        end: true,
        path: body['path']?.toString() ?? path,
      );
    } on FileReadException {
      rethrow;
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Read a text file's full content as a UTF-8 string.
  ///
  /// POST /files/content — 1Panel v2 返回明文 content（非 base64），原样返回。
  static Future<String> readFile(String path) async {
    try {
      final res = await ApiClient.instance.post(
        '/files/content',
        data: {'path': path},
      );
      final body = _parseBody(res);
      final content = body['content'];
      if (content is! String) {
        throw const FileReadException('响应缺少 content 字段');
      }
      return content;
    } on FileReadException {
      rethrow;
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Read a file's raw bytes (for binary / image preview).
  ///
  /// GET /files/download — 返回原始字节流（非 base64）。
  static Future<Uint8List> readFileBytes(String path) async {
    try {
      final res = await ApiClient.instance.getBytes(
        '/files/download',
        params: {'path': path},
      );
      return Uint8List.fromList(res.data ?? []);
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Save file content
  /// POST /files/save
  static Future<void> save(String path, String content) async {
    await ApiClient.instance.post(
      '/files/save',
      data: {'path': path, 'content': content},
    );
  }

  /// Create file or directory
  /// POST /files
  /// mode: 数字权限如 493 (0755), null=API 默认
  static Future<void> create(
    String path, {
    bool isDir = false,
    int? mode,
    String? content,
  }) async {
    final data = <String, dynamic>{'path': path, 'isDir': isDir};
    if (mode != null) data['mode'] = mode;
    if (content != null) data['content'] = content;
    await ApiClient.instance.post('/files', data: data);
  }

  /// Rename file/directory
  /// POST /files/rename
  static Future<void> rename(String oldName, String newName) async {
    await ApiClient.instance.post(
      '/files/rename',
      data: {'oldName': oldName, 'newName': newName},
    );
  }

  /// Delete file/directory
  /// POST /files/del
  static Future<void> delete(String path, {bool isDir = false}) async {
    await ApiClient.instance.post(
      '/files/del',
      data: {'path': path, 'isDir': isDir},
    );
  }

  /// Batch delete
  /// POST /files/batch/del
  static Future<void> batchDelete(List<String> paths) async {
    await ApiClient.instance.post('/files/batch/del', data: {'paths': paths});
  }

  /// Change file mode (permissions)
  /// POST /files/mode
  /// mode: 数字权限如 420 (0644)
  static Future<void> changeMode(String path, int mode) async {
    await ApiClient.instance.post(
      '/files/mode',
      data: {'path': path, 'mode': mode},
    );
  }

  /// Change file owner
  /// POST /files/owner
  static Future<void> changeOwner(
    String path,
    String user,
    String group,
  ) async {
    await ApiClient.instance.post(
      '/files/owner',
      data: {'path': path, 'user': user, 'group': group},
    );
  }

  /// Move file(s) to new location
  /// POST /files/move
  static Future<void> move(List<String> oldPaths, String newPath) async {
    await ApiClient.instance.post(
      '/files/move',
      data: {'oldPaths': oldPaths, 'newPath': newPath, 'type': 'move'},
    );
  }

  /// Compress files
  /// POST /files/compress
  static Future<void> compress(
    List<String> files,
    String dst,
    String name, {
    String type = 'zip',
  }) async {
    await ApiClient.instance.post(
      '/files/compress',
      data: {'files': files, 'dst': dst, 'name': name, 'type': type},
    );
  }

  /// Decompress file
  /// POST /files/decompress
  static Future<void> decompress(
    String path,
    String dst, {
    String type = 'zip',
  }) async {
    await ApiClient.instance.post(
      '/files/decompress',
      data: {'path': path, 'dst': dst, 'type': type},
    );
  }

  /// Get directory size
  /// POST /files/size
  static Future<DirSizeInfo> getSize(String path) async {
    final res = await ApiClient.instance.post(
      '/files/size',
      data: {'path': path},
    );
    final body = _parseBody(res);
    return DirSizeInfo(
      size: (body['size'] as num?)?.toInt() ?? 0,
      total: (body['total'] as num?)?.toInt() ?? 0,
      path: body['path']?.toString() ?? path,
    );
  }

  /// Get system mounts / disk info
  /// POST /files/mount
  static Future<List<MountInfo>> getMount() async {
    final res = await ApiClient.instance.post('/files/mount');
    final data = res.data['data'];
    if (data is List) {
      return data
          .map((e) => MountInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get system users and groups
  /// POST /files/user/group
  /// Response: users = [{username, group}], groups = [string]
  static Future<UserGroupInfo> getUserGroup() async {
    final res = await ApiClient.instance.post('/files/user/group');
    final body = _parseBody(res);
    final users =
        (body['users'] as List?)?.map((e) {
          if (e is Map) {
            final uname =
                e['username']?.toString() ?? e['user']?.toString() ?? '';
            final gname = e['group']?.toString() ?? '';
            return '$uname ($gname)';
          }
          return e.toString();
        }).toList() ??
        [];
    final groups =
        (body['groups'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return UserGroupInfo(users: users, groups: groups);
  }

  /// Download file — returns bytes
  /// GET /files/download?path=xxx
  static Future<List<int>> download(String path) async {
    try {
      final res = await ApiClient.instance.getBytes(
        '/files/download',
        params: {'path': path},
      );
      return res.data ?? [];
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Upload file (multipart)
  /// POST /files/upload
  static Future<void> upload(String path, String localFilePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localFilePath),
      'path': path,
    });
    await ApiClient.instance.post('/files/upload', data: formData);
  }

  /// Upload file bytes (multipart)
  /// POST /files/upload
  static Future<void> uploadBytes(
    String path,
    String fileName,
    List<int> bytes,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'path': path,
    });
    await ApiClient.instance.post('/files/upload', data: formData);
  }

  /// Check if file exists
  /// POST /files/check
  static Future<bool> checkExists(String path) async {
    final res = await ApiClient.instance.post(
      '/files/check',
      data: {'path': path},
    );
    return res.data['data'] == true;
  }

  /// Read file content by line (1Panel v2 专用端点)。
  ///
  /// POST /files/read — 支持按类型读取任务日志（type=task, name=taskID）、
  /// 慢日志（type=mysql-slow-logs, name=实例名）等。返回分页行。
  static Future<FileReadResult> readByLineFile({
    required String type,
    String name = '',
    String taskID = '',
    int id = 0,
    int page = 1,
    int pageSize = 500,
    bool latest = true,
  }) async {
    try {
      final res = await ApiClient.instance.post(
        '/files/read',
        data: {
          'page': page,
          'pageSize': pageSize,
          'type': type,
          'ID': id,
          'name': taskID.isNotEmpty ? taskID : name,
          'latest': latest,
        },
      );
      final body = _parseBody(res);
      return FileReadResult(
        end: body['end'] as bool? ?? true,
        path: body['path']?.toString() ?? '',
        total: (body['total'] as num?)?.toInt() ?? 0,
        taskStatus: body['taskStatus']?.toString() ?? '',
        lines:
            (body['lines'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        totalLines: (body['totalLines'] as num?)?.toInt() ?? 0,
      );
    } on FileReadException {
      rethrow;
    } on DioException catch (e) {
      throw FileReadException(e.message ?? '网络错误', e.response?.statusCode);
    } on Exception catch (e) {
      throw FileReadException(e.toString());
    }
  }

  /// Parse 1Panel API response body
  static Map<String, dynamic> _parseBody(Response res) {
    final data = res.data;
    if (data is! Map) throw Exception('响应格式错误: 期望 JSON');
    final body = data as Map<String, dynamic>;
    if (body.containsKey('code') && body['code'] != 200) {
      throw Exception(body['message'] ?? '接口返回异常(code=${body['code']})');
    }
    if (body.containsKey('data') && body['data'] is Map) {
      return body['data'] as Map<String, dynamic>;
    }
    return body;
  }

  static List<FileItem> _parseItems(dynamic items) {
    if (items is! List) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => FileItem.fromJson(e))
        .toList();
  }
}

class FileListResult {
  final List<FileItem> items;
  final int total;

  FileListResult({required this.items, required this.total});
}

class FileReadResult {
  final bool end;
  final String path;
  final int total;
  final String taskStatus;
  final List<String> lines;
  final int totalLines;

  FileReadResult({
    required this.end,
    required this.path,
    required this.total,
    required this.taskStatus,
    required this.lines,
    required this.totalLines,
  });

  bool get isExecuting => taskStatus.toLowerCase() == 'executing';
}

class FileLineResult {
  final List<String> lines;
  final int total;
  final int totalLines;
  final bool end;
  final String path;

  FileLineResult({
    required this.lines,
    required this.total,
    required this.totalLines,
    required this.end,
    required this.path,
  });
}

class DirSizeInfo {
  final int size;
  final int total;
  final String path;

  DirSizeInfo({required this.size, required this.total, required this.path});
}

class MountInfo {
  final String path;
  final String device;
  final String? fsType;
  final String? mountPoint;

  MountInfo({
    required this.path,
    required this.device,
    this.fsType,
    this.mountPoint,
  });

  factory MountInfo.fromJson(Map<String, dynamic> json) => MountInfo(
    path: json['path']?.toString() ?? json['mountPoint']?.toString() ?? '',
    device: json['device']?.toString() ?? '',
    fsType: json['fsType']?.toString(),
    mountPoint: json['mountPoint']?.toString(),
  );
}

class UserGroupInfo {
  final List<String> users;
  final List<String> groups;

  UserGroupInfo({required this.users, required this.groups});
}
