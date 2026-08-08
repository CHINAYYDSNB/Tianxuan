import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/file_api.dart';
import '../models/backup_record.dart';
import '../models/database.dart';
import '../models/task_log.dart';
import '../services/backup_service.dart';
import 'database_provider.dart';
import 'ssh_connection_provider.dart';

/// 备份服务：API First, SSH Fallback。
final backupServiceProvider = Provider<BackupService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return FallbackBackupService(ssh: ssh);
});

/// 按实例 id 查找实例。
DatabaseInstance? _findInstance(Ref ref, String id) {
  for (final inst in ref.watch(databaseInstancesProvider)) {
    if (inst.id == id) return inst;
  }
  return null;
}

/// 备份记录分页列表状态。
class BackupListState {
  final List<BackupRecord> records;
  final int total;
  final bool isLoadingMore;
  final bool hasMore;

  const BackupListState({
    required this.records,
    required this.total,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  BackupListState copyWith({
    List<BackupRecord>? records,
    int? total,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return BackupListState(
      records: records ?? this.records,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 备份记录控制器：分页加载 + 合并 size。
class BackupRecordsController
    extends
        AutoDisposeFamilyAsyncNotifier<
          BackupListState,
          ({String instanceId, String detailName})
        > {
  static const _pageSize = 10;

  @override
  Future<BackupListState> build(({String instanceId, String detailName}) arg) =>
      _load(1);

  Future<BackupListState> _load(int page) async {
    final inst = _findInstance(ref, arg.instanceId);
    if (inst == null) {
      return const BackupListState(records: [], total: 0);
    }
    final svc = ref.read(backupServiceProvider);
    final result = await svc.listRecords(
      inst,
      arg.detailName,
      page: page,
      pageSize: _pageSize,
    );
    var records = result.records;
    if (records.isNotEmpty) {
      final sizes = await svc.recordSizes(
        inst,
        arg.detailName,
        page: page,
        pageSize: _pageSize,
      );
      records = [for (final r in records) r.copyWith(size: sizes[r.id])];
    }
    return BackupListState(
      records: records,
      total: result.total,
      hasMore: records.length >= _pageSize,
    );
  }

  Future<void> refresh() async {
    state = AsyncData(await _load(1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = current.records.length ~/ _pageSize + 1;
      final loaded = await _load(nextPage);
      state = AsyncData(
        current.copyWith(
          records: [...current.records, ...loaded.records],
          total: loaded.total,
          hasMore: loaded.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<String> backup({
    String secret = '',
    String description = '',
    List<String> args = const [],
  }) async {
    final inst = _findInstance(ref, arg.instanceId);
    if (inst == null) throw Exception('实例不存在');
    final taskID = await ref
        .read(backupServiceProvider)
        .backup(
          inst,
          arg.detailName,
          secret: secret,
          description: description,
          args: args,
        );
    await refresh();
    return taskID;
  }

  Future<String> recover(BackupRecord record, {String secret = ''}) async {
    final inst = _findInstance(ref, arg.instanceId);
    if (inst == null) throw Exception('实例不存在');
    final taskID = await ref
        .read(backupServiceProvider)
        .recover(inst, arg.detailName, record, secret: secret);
    await refresh();
    return taskID;
  }

  Future<void> delete(BackupRecord record) async {
    await ref.read(backupServiceProvider).deleteRecords([record.id]);
    await refresh();
  }

  Future<void> download(BackupRecord record) async {
    await ref.read(backupServiceProvider).downloadRecord(record);
  }
}

final backupRecordsProvider = AsyncNotifierProvider.autoDispose
    .family<
      BackupRecordsController,
      BackupListState,
      ({String instanceId, String detailName})
    >(BackupRecordsController.new);

/// 任务日志轮询。
class TaskLogPoller {
  TaskLogPoller(this._reader);

  final Future<TaskLog> Function() _reader;
  Timer? _timer;
  bool _done = false;

  void Function(TaskLog log)? onUpdate;
  void Function(String error)? onError;

  /// 从 taskID 构造轮询器（走 /files/read type=task）。
  factory TaskLogPoller.forTask(
    String taskID, {
    Duration interval = const Duration(seconds: 2),
  }) {
    return TaskLogPoller(() async {
      final res = await FileApi.readByLineFile(
        type: 'task',
        taskID: taskID,
        page: 1,
        pageSize: 500,
        latest: true,
      );
      return TaskLog(
        end: res.end,
        path: res.path,
        total: res.total,
        taskStatus: res.taskStatus,
        lines: res.lines,
        totalLines: res.totalLines,
      );
    });
  }

  void start({Duration interval = const Duration(seconds: 2)}) {
    _pollOnce();
    _timer = Timer.periodic(interval, (_) => _pollOnce());
  }

  Future<void> _pollOnce() async {
    if (_done) return;
    try {
      final log = await _reader();
      onUpdate?.call(log);
      if (!log.isExecuting && log.end) {
        _done = true;
        _stop();
      }
    } catch (e) {
      onError?.call('$e');
      _stop();
    }
  }

  void stop() {
    _stop();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
