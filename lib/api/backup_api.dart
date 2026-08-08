import 'package:dio/dio.dart';
import '../models/backup_record.dart';
import 'client.dart';

/// 1Panel 备份 API（对齐 Mono-Dash BackupApi）。
///
/// 备份/恢复是异步任务：调用方生成 taskID（uuid），接口受理后通过
/// [FileReadApi.readTaskLog] 轮询任务进度。
class BackupApi {
  static const _local = 'local';

  /// POST /backups/record/search — 分页查询备份记录。
  static Future<BackupRecordPage> searchRecords(
    BackupRecordSearchReq req,
  ) async {
    final res = await ApiClient.instance.post(
      '/backups/record/search',
      queryParameters: {'operateNode': _local},
      data: req.toJson(),
    );
    final data = _dataOf(res);
    if (data is! Map) return const BackupRecordPage(records: [], total: 0);
    final items = data['items'];
    final list = items is List
        ? items
              .whereType<Map>()
              .map((e) => BackupRecord.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <BackupRecord>[];
    return BackupRecordPage(
      records: list,
      total: (data['total'] as num?)?.toInt() ?? list.length,
    );
  }

  /// POST /backups/record/size — 查询记录大小。
  static Future<Map<int, int>> recordSizes(BackupRecordSearchReq req) async {
    final res = await ApiClient.instance.post(
      '/backups/record/size',
      queryParameters: {'operateNode': _local},
      data: req.toJson(),
    );
    final data = _dataOf(res);
    if (data is! List) return const {};
    return {
      for (final e in data.whereType<Map>())
        (e['id'] as num?)?.toInt() ?? 0: (e['size'] as num?)?.toInt() ?? 0,
    };
  }

  /// POST /backups/record/del — 删除备份记录。
  static Future<void> deleteRecords(List<int> ids) async {
    final res = await ApiClient.instance.post(
      '/backups/record/del',
      data: {'ids': ids, 'node': _local},
    );
    _checkCode(res);
  }

  /// POST /backups/backup — 执行数据库备份。
  static Future<void> backupDatabase({
    required String type,
    required String name,
    required String detailName,
    required String secret,
    required String taskID,
    required String description,
    List<String> args = const [],
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/backup',
      queryParameters: {'operateNode': _local},
      data: {
        'type': type,
        'name': name,
        'detailName': detailName,
        'secret': secret,
        'taskID': taskID,
        'description': description,
        'args': args,
      },
    );
    _checkCode(res);
  }

  /// POST /backups/recover — 从备份记录恢复数据库。
  static Future<void> recoverDatabase({
    required int downloadAccountID,
    required String type,
    required String name,
    required String detailName,
    required String file,
    required String secret,
    required String taskID,
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/recover',
      queryParameters: {'operateNode': _local},
      data: {
        'downloadAccountID': downloadAccountID,
        'type': type,
        'name': name,
        'detailName': detailName,
        'file': file,
        'secret': secret,
        'taskID': taskID,
      },
    );
    _checkCode(res);
  }

  /// POST /backups/record/download — 下载备份记录，返回服务器文件路径。
  static Future<String> downloadRecord({
    required int downloadAccountID,
    required String fileDir,
    required String fileName,
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/record/download',
      data: {
        'downloadAccountID': downloadAccountID,
        'fileDir': fileDir,
        'fileName': fileName,
      },
    );
    return _dataOf(res)?.toString() ?? '';
  }

  /// POST /backups/upload — 将服务器上已有文件复制到导入目录。
  static Future<void> uploadForRecover({
    required String filePath,
    required String targetDir,
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/upload',
      data: {'filePath': filePath, 'targetDir': targetDir},
    );
    _checkCode(res);
  }

  /// POST /backups/recover/byupload — 从上传文件恢复。
  static Future<void> recoverByUpload({
    required int downloadAccountID,
    required String type,
    required String name,
    required String detailName,
    required String file,
    required String secret,
    required String taskID,
    int timeout = 0,
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/recover/byupload',
      queryParameters: {'operateNode': _local},
      data: {
        'downloadAccountID': downloadAccountID,
        'type': type,
        'name': name,
        'detailName': detailName,
        'file': file,
        'secret': secret,
        'taskID': taskID,
        'timeout': timeout,
      },
    );
    _checkCode(res);
  }

  /// GET /backups/options — 备份账号选项列表。
  static Future<List<BackupOption>> loadBackupOptions() async {
    final res = await ApiClient.instance.get('/backups/options');
    final data = _dataOf(res);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => BackupOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /backups/search — 搜索备份账号。
  static Future<BackupAccountPage> searchAccounts({
    int page = 1,
    int pageSize = 100,
    String type = '',
    String name = '',
  }) async {
    final res = await ApiClient.instance.post(
      '/backups/search',
      data: {'page': page, 'pageSize': pageSize, 'type': type, 'name': name},
    );
    final data = _dataOf(res);
    if (data is! Map) return const BackupAccountPage(accounts: [], total: 0);
    final items = data['items'];
    return BackupAccountPage(
      accounts: items is List
          ? items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// POST /backups — 创建备份账号。
  static Future<void> createAccount(Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post('/backups', data: data);
    _checkCode(res);
  }

  /// POST /backups/update — 更新备份账号。
  static Future<void> updateAccount(Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post('/backups/update', data: data);
    _checkCode(res);
  }

  /// POST /backups/del — 删除备份账号。
  static Future<void> deleteAccount(int id) async {
    final res = await ApiClient.instance.post('/backups/del', data: {'id': id});
    _checkCode(res);
  }

  /// POST /backups/conn/check — 测试备份账号连接。
  static Future<void> checkConnection(Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post(
      '/backups/conn/check',
      data: data,
    );
    _checkCode(res);
  }

  /// POST /backups/buckets — 获取对象存储桶列表。
  static Future<List<dynamic>> listBuckets(Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post('/backups/buckets', data: data);
    final result = _dataOf(res);
    return result is List ? result : const [];
  }

  /// POST /backups/refresh/token — 刷新 OAuth 类型账号 token。
  static Future<void> refreshToken(int id) async {
    final res = await ApiClient.instance.post(
      '/backups/refresh/token',
      data: {'id': id},
    );
    _checkCode(res);
  }

  /// GET /backups/local — 本地备份目录。
  static Future<String> getLocalDir() async {
    final res = await ApiClient.instance.get('/backups/local');
    return _dataOf(res)?.toString() ?? '';
  }

  static dynamic _dataOf(Response res) {
    final data = res.data;
    if (data is Map) {
      if (data.containsKey('code') && data['code'] != 200) {
        throw Exception(
          data['message']?.toString() ?? '接口返回异常(code=${data['code']})',
        );
      }
      return data['data'];
    }
    return null;
  }

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(
        data['message']?.toString() ?? '接口返回异常(code=${data['code']})',
      );
    }
  }
}

class BackupRecordPage {
  final List<BackupRecord> records;
  final int total;

  const BackupRecordPage({required this.records, required this.total});
}

class BackupAccountPage {
  final List<Map<String, dynamic>> accounts;
  final int total;

  const BackupAccountPage({required this.accounts, required this.total});
}
