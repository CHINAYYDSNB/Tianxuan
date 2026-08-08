import '../api/backup_api.dart';
import '../models/backup_record.dart';
import '../models/database.dart';
import 'ssh_command_service.dart';
import 'ssh_database_service.dart';

/// 数据库备份/恢复操作服务抽象。
/// API First, SSH Fallback。
abstract class BackupService {
  Future<BackupRecordPage> listRecords(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  });

  Future<Map<int, int>> recordSizes(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  });

  Future<void> deleteRecords(List<int> ids);

  /// 执行备份，返回 taskID。
  Future<String> backup(
    DatabaseInstance inst,
    String detailName, {
    String secret = '',
    String description = '',
    List<String> args = const [],
  });

  /// 从备份记录恢复，返回 taskID。
  Future<String> recover(
    DatabaseInstance inst,
    String detailName,
    BackupRecord record, {
    String secret = '',
  });

  Future<String> downloadRecord(BackupRecord record);

  Future<List<BackupOption>> loadBackupOptions();

  Future<BackupAccountPage> searchAccounts({int page = 1, int pageSize = 100});

  Future<void> createAccount(Map<String, dynamic> data);

  Future<void> updateAccount(Map<String, dynamic> data);

  Future<void> deleteAccount(int id);

  Future<void> checkConnection(Map<String, dynamic> data);

  Future<List<dynamic>> listBuckets(Map<String, dynamic> data);

  Future<void> refreshToken(int id);

  Future<String> getLocalDir();
}

/// 1Panel API 实现。
class ApiBackupService implements BackupService {
  @override
  Future<BackupRecordPage> listRecords(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) => BackupApi.searchRecords(
    BackupRecordSearchReq(
      page: page,
      pageSize: pageSize,
      type: inst.type.apiType,
      name: inst.name,
      detailName: detailName,
    ),
  );

  @override
  Future<Map<int, int>> recordSizes(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) => BackupApi.recordSizes(
    BackupRecordSearchReq(
      page: page,
      pageSize: pageSize,
      type: inst.type.apiType,
      name: inst.name,
      detailName: detailName,
    ),
  );

  @override
  Future<void> deleteRecords(List<int> ids) => BackupApi.deleteRecords(ids);

  @override
  Future<String> backup(
    DatabaseInstance inst,
    String detailName, {
    String secret = '',
    String description = '',
    List<String> args = const [],
  }) async {
    final taskID = _newTaskId();
    await BackupApi.backupDatabase(
      type: inst.type.apiType,
      name: inst.name,
      detailName: detailName,
      secret: secret,
      taskID: taskID,
      description: description,
      args: args,
    );
    return taskID;
  }

  @override
  Future<String> recover(
    DatabaseInstance inst,
    String detailName,
    BackupRecord record, {
    String secret = '',
  }) async {
    final taskID = _newTaskId();
    await BackupApi.recoverDatabase(
      downloadAccountID: record.downloadAccountID,
      type: inst.type.apiType,
      name: inst.name,
      detailName: detailName,
      file: record.filePath,
      secret: secret,
      taskID: taskID,
    );
    return taskID;
  }

  @override
  Future<String> downloadRecord(BackupRecord record) =>
      BackupApi.downloadRecord(
        downloadAccountID: record.downloadAccountID,
        fileDir: record.fileDir,
        fileName: record.fileName,
      );

  @override
  Future<List<BackupOption>> loadBackupOptions() =>
      BackupApi.loadBackupOptions();

  @override
  Future<BackupAccountPage> searchAccounts({
    int page = 1,
    int pageSize = 100,
  }) => BackupApi.searchAccounts(page: page, pageSize: pageSize);

  @override
  Future<void> createAccount(Map<String, dynamic> data) =>
      BackupApi.createAccount(data);

  @override
  Future<void> updateAccount(Map<String, dynamic> data) =>
      BackupApi.updateAccount(data);

  @override
  Future<void> deleteAccount(int id) => BackupApi.deleteAccount(id);

  @override
  Future<void> checkConnection(Map<String, dynamic> data) =>
      BackupApi.checkConnection(data);

  @override
  Future<List<dynamic>> listBuckets(Map<String, dynamic> data) =>
      BackupApi.listBuckets(data);

  @override
  Future<void> refreshToken(int id) => BackupApi.refreshToken(id);

  @override
  Future<String> getLocalDir() => BackupApi.getLocalDir();

  static String _newTaskId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'tx-${now.toRadixString(16)}-${(now % 0xFFFF).toRadixString(16)}';
  }
}

/// SSH 实现：用 mysqldump / pg_dump / mongodump / redis-cli 直接备份到服务器目录。
class SshBackupService implements BackupService {
  final SshCommandService _ssh;

  /// 备份目录（可通过 [backupDir] 覆盖）。
  String backupDir;

  SshBackupService(
    this._ssh, {
    this.backupDir = '/opt/1panel/.tianxuan-backup',
  });

  @override
  Future<BackupRecordPage> listRecords(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final dir = _escapeSingle(backupDir);
    final out = await _ssh.execute(
      'mkdir -p "$dir" 2>/dev/null; ls -1 "$dir" 2>/dev/null | grep -E "\\." | tail -n +1',
      timeout: const Duration(seconds: 10),
    );
    if (!out.isSuccess) return const BackupRecordPage(records: [], total: 0);
    final all = <BackupRecord>[];
    for (final line in out.stdout.split('\n')) {
      final f = line.trim();
      if (f.isEmpty) continue;
      all.add(
        BackupRecord(
          id: all.length + 1,
          createdAt: null,
          accountType: 'LOCAL',
          accountName: 'local',
          fileName: f,
          fileDir: backupDir,
          status: 'success',
        ),
      );
    }
    final start = (page - 1) * pageSize;
    if (start >= all.length) {
      return const BackupRecordPage(records: [], total: 0);
    }
    final end = (start + pageSize).clamp(0, all.length);
    return BackupRecordPage(
      records: all.reversed.toList().sublist(start, end),
      total: all.length,
    );
  }

  @override
  Future<Map<int, int>> recordSizes(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final out = await _ssh.execute(
      'du -sb "${_escapeSingle(backupDir)}"/* 2>/dev/null',
      timeout: const Duration(seconds: 10),
    );
    final map = <int, int>{};
    if (!out.isSuccess) return map;
    var i = 1;
    for (final line in out.stdout.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) map[i++] = int.tryParse(parts[0]) ?? 0;
    }
    return map;
  }

  @override
  Future<void> deleteRecords(List<int> ids) async {
    for (final id in ids) {
      await _ssh.execute(
        'rm -rf "${_escapeSingle(backupDir)}"/*.$id 2>/dev/null',
        timeout: const Duration(seconds: 10),
      );
    }
  }

  @override
  Future<String> backup(
    DatabaseInstance inst,
    String detailName, {
    String secret = '',
    String description = '',
    List<String> args = const [],
  }) async {
    final dir = _escapeSingle(backupDir);
    await _ssh.execute('mkdir -p "$dir"', timeout: const Duration(seconds: 10));
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filename = '${inst.name}_${detailName}_$ts.sql';
    final target = '"$dir/$filename"';
    final cmd = SshDatabaseCli.dumpCommand(inst, detailName, target);
    final out = await _ssh.execute(cmd, timeout: const Duration(seconds: 120));
    if (!out.isSuccess) {
      throw Exception(out.stderr.isEmpty ? '备份失败' : out.stderr);
    }
    return filename;
  }

  @override
  Future<String> recover(
    DatabaseInstance inst,
    String detailName,
    BackupRecord record, {
    String secret = '',
  }) async {
    final file = record.filePath.isEmpty ? record.fileName : record.filePath;
    final cmd = SshDatabaseCli.restoreCommand(inst, detailName, '"$file"');
    final out = await _ssh.execute(cmd, timeout: const Duration(seconds: 300));
    if (!out.isSuccess) {
      throw Exception(out.stderr.isEmpty ? '恢复失败' : out.stderr);
    }
    return record.fileName;
  }

  @override
  Future<String> downloadRecord(BackupRecord record) async {
    final file = record.filePath.isEmpty ? record.fileName : record.filePath;
    final out = await _ssh.execute(
      'cat "$file"',
      timeout: const Duration(seconds: 30),
    );
    if (!out.isSuccess) throw Exception('下载失败');
    return out.stdout;
  }

  @override
  Future<List<BackupOption>> loadBackupOptions() async {
    return const [BackupOption(type: 'LOCAL', name: 'local', id: 0)];
  }

  @override
  Future<BackupAccountPage> searchAccounts({
    int page = 1,
    int pageSize = 100,
  }) async => const BackupAccountPage(accounts: [], total: 0);

  @override
  Future<void> createAccount(Map<String, dynamic> data) async {
    throw Exception('SSH 模式暂不支持创建备份账号');
  }

  @override
  Future<void> updateAccount(Map<String, dynamic> data) async {
    throw Exception('SSH 模式暂不支持修改备份账号');
  }

  @override
  Future<void> deleteAccount(int id) async {
    throw Exception('SSH 模式暂不支持删除备份账号');
  }

  @override
  Future<void> checkConnection(Map<String, dynamic> data) async {
    throw Exception('SSH 模式暂不支持测试备份账号');
  }

  @override
  Future<List<dynamic>> listBuckets(Map<String, dynamic> data) async {
    return const [];
  }

  @override
  Future<void> refreshToken(int id) async {
    throw Exception('SSH 模式暂不支持刷新 token');
  }

  @override
  Future<String> getLocalDir() async => backupDir;

  static String _escapeSingle(String s) => s.replaceAll("'", "'\\''");
}

/// API First, SSH Fallback。
class FallbackBackupService implements BackupService {
  final ApiBackupService _api;
  final SshBackupService? _ssh;

  FallbackBackupService({
    SshCommandService? ssh,
    String backupDir = '/opt/1panel/.tianxuan-backup',
  }) : _api = ApiBackupService(),
       _ssh = ssh != null ? SshBackupService(ssh, backupDir: backupDir) : null;

  bool get _canSsh => _ssh != null;

  @override
  Future<BackupRecordPage> listRecords(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        return await _api.listRecords(
          inst,
          detailName,
          page: page,
          pageSize: pageSize,
        );
      } catch (_) {}
    }
    if (_canSsh) {
      return _ssh!.listRecords(
        inst,
        detailName,
        page: page,
        pageSize: pageSize,
      );
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<Map<int, int>> recordSizes(
    DatabaseInstance inst,
    String detailName, {
    int page = 1,
    int pageSize = 10,
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        return await _api.recordSizes(
          inst,
          detailName,
          page: page,
          pageSize: pageSize,
        );
      } catch (_) {}
    }
    if (_canSsh) {
      return _ssh!.recordSizes(
        inst,
        detailName,
        page: page,
        pageSize: pageSize,
      );
    }
    return const {};
  }

  @override
  Future<void> deleteRecords(List<int> ids) async {
    try {
      await _api.deleteRecords(ids);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.deleteRecords(ids);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<String> backup(
    DatabaseInstance inst,
    String detailName, {
    String secret = '',
    String description = '',
    List<String> args = const [],
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        return await _api.backup(
          inst,
          detailName,
          secret: secret,
          description: description,
          args: args,
        );
      } catch (_) {}
    }
    if (_canSsh) {
      return _ssh!.backup(
        inst,
        detailName,
        secret: secret,
        description: description,
        args: args,
      );
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<String> recover(
    DatabaseInstance inst,
    String detailName,
    BackupRecord record, {
    String secret = '',
  }) async {
    if (inst.fromApi || inst.isRemote) {
      try {
        return await _api.recover(inst, detailName, record, secret: secret);
      } catch (_) {}
    }
    if (_canSsh) {
      return _ssh!.recover(inst, detailName, record, secret: secret);
    }
    throw Exception('无可用的连接方式');
  }

  @override
  Future<String> downloadRecord(BackupRecord record) async {
    try {
      return await _api.downloadRecord(record);
    } catch (_) {}
    if (_canSsh) return _ssh!.downloadRecord(record);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<List<BackupOption>> loadBackupOptions() async {
    try {
      return await _api.loadBackupOptions();
    } catch (_) {}
    if (_canSsh) return _ssh!.loadBackupOptions();
    return const [];
  }

  @override
  Future<BackupAccountPage> searchAccounts({
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      return await _api.searchAccounts(page: page, pageSize: pageSize);
    } catch (_) {}
    if (_canSsh) {
      return _ssh!.searchAccounts(page: page, pageSize: pageSize);
    }
    return const BackupAccountPage(accounts: [], total: 0);
  }

  @override
  Future<void> createAccount(Map<String, dynamic> data) async {
    try {
      await _api.createAccount(data);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.createAccount(data);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> updateAccount(Map<String, dynamic> data) async {
    try {
      await _api.updateAccount(data);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.updateAccount(data);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> deleteAccount(int id) async {
    try {
      await _api.deleteAccount(id);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.deleteAccount(id);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<void> checkConnection(Map<String, dynamic> data) async {
    try {
      await _api.checkConnection(data);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.checkConnection(data);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<List<dynamic>> listBuckets(Map<String, dynamic> data) async {
    try {
      return await _api.listBuckets(data);
    } catch (_) {}
    if (_canSsh) return _ssh!.listBuckets(data);
    return const [];
  }

  @override
  Future<void> refreshToken(int id) async {
    try {
      await _api.refreshToken(id);
      return;
    } catch (_) {}
    if (_canSsh) return _ssh!.refreshToken(id);
    throw Exception('无可用的连接方式');
  }

  @override
  Future<String> getLocalDir() async {
    try {
      return await _api.getLocalDir();
    } catch (_) {}
    if (_canSsh) return _ssh!.getLocalDir();
    return '/opt/1panel/backup';
  }
}
