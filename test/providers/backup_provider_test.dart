import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/api/backup_api.dart';
import 'package:tianxuan/models/backup_record.dart';
import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/models/task_log.dart';
import 'package:tianxuan/providers/backup_provider.dart';
import 'package:tianxuan/providers/database_provider.dart';
import 'package:tianxuan/services/backup_service.dart';

class _MockBackupService extends Mock implements BackupService {}

const _inst = DatabaseInstance(
  id: 'a1',
  type: DbType.mysql,
  name: 'mysql',
  source: 'api',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const DatabaseInstance(id: 'fb', type: DbType.mysql, name: 'fb'),
    );
    registerFallbackValue(const BackupRecord(id: 0, fileName: 'fb.sql'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('backupServiceProvider 返回 FallbackBackupService', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(backupServiceProvider), isA<FallbackBackupService>());
  });

  test('backupRecordsProvider 加载记录并合并 size', () async {
    final svc = _MockBackupService();
    when(
      () => svc.listRecords(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const BackupRecordPage(
        records: [BackupRecord(id: 1, fileName: 'a.sql', status: 'success')],
        total: 1,
      ),
    );
    when(
      () => svc.recordSizes(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => {1: 1024});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(databaseInstancesProvider.notifier).add(_inst);
    final overridden = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(svc)],
    );
    addTearDown(overridden.dispose);
    await overridden.read(databaseInstancesProvider.notifier).add(_inst);

    final state = await overridden.read(
      backupRecordsProvider((instanceId: 'a1', detailName: 'appdb')).future,
    );
    expect(state.records.first.size, 1024);
    expect(state.total, 1);
  });

  test('实例不存在返回空', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = await container.read(
      backupRecordsProvider((instanceId: 'nope', detailName: 'appdb')).future,
    );
    expect(state.records, isEmpty);
  });

  test('backup/recover/delete 调服务并返回 taskID', () async {
    final svc = _MockBackupService();
    when(
      () => svc.backup(
        any(),
        any(),
        secret: any(named: 'secret'),
        description: any(named: 'description'),
        args: any(named: 'args'),
      ),
    ).thenAnswer((_) async => 'tx-1');
    when(
      () => svc.recover(any(), any(), any(), secret: any(named: 'secret')),
    ).thenAnswer((_) async => 'tx-2');
    when(() => svc.deleteRecords(any())).thenAnswer((_) async {});
    when(
      () => svc.listRecords(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const BackupRecordPage(records: [], total: 0));
    when(
      () => svc.recordSizes(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => {});

    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(svc)],
    );
    addTearDown(container.dispose);
    await container.read(databaseInstancesProvider.notifier).add(_inst);

    final notifier = container.read(
      backupRecordsProvider((instanceId: 'a1', detailName: 'appdb')).notifier,
    );
    expect(await notifier.backup(secret: 's', description: 'd'), 'tx-1');
    const record = BackupRecord(id: 1, fileName: 'a.sql');
    expect(await notifier.recover(record, secret: 's'), 'tx-2');
    await notifier.delete(record);

    verify(() => svc.deleteRecords([1])).called(1);
  });

  test('loadMore 合并记录', () async {
    final svc = _MockBackupService();
    when(
      () => svc.listRecords(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => BackupRecordPage(
        records: [
          BackupRecord(id: 1, fileName: 'a.sql', status: 'success'),
          BackupRecord(id: 2, fileName: 'b.sql', status: 'success'),
          BackupRecord(id: 3, fileName: 'c.sql', status: 'success'),
          BackupRecord(id: 4, fileName: 'd.sql', status: 'success'),
          BackupRecord(id: 5, fileName: 'e.sql', status: 'success'),
          BackupRecord(id: 6, fileName: 'f.sql', status: 'success'),
          BackupRecord(id: 7, fileName: 'g.sql', status: 'success'),
          BackupRecord(id: 8, fileName: 'h.sql', status: 'success'),
          BackupRecord(id: 9, fileName: 'i.sql', status: 'success'),
          BackupRecord(id: 10, fileName: 'j.sql', status: 'success'),
        ],
        total: 20,
      ),
    );
    when(
      () => svc.recordSizes(
        any(),
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => {});

    final container = ProviderContainer(
      overrides: [backupServiceProvider.overrideWithValue(svc)],
    );
    addTearDown(container.dispose);
    await container.read(databaseInstancesProvider.notifier).add(_inst);

    final notifier = container.read(
      backupRecordsProvider((instanceId: 'a1', detailName: 'appdb')).notifier,
    );
    await notifier.refresh();
    expect(notifier.state.valueOrNull?.hasMore, isTrue);
    await notifier.loadMore();
    expect(notifier.state.valueOrNull?.records.length, greaterThan(10));
  });

  test('TaskLogPoller 轮询到完成自动停止', () async {
    var calls = 0;
    final poller = TaskLogPoller(() async {
      calls++;
      if (calls == 1) {
        return const TaskLog(
          end: false,
          taskStatus: 'executing',
          lines: ['start'],
        );
      }
      return const TaskLog(end: true, taskStatus: 'done', lines: ['done']);
    });
    TaskLog? last;
    poller.onUpdate = (log) => last = log;
    poller.start(interval: const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(last?.isExecuting, isFalse);
    poller.stop();
  });

  test('TaskLogPoller 出错回调并停止', () async {
    final poller = TaskLogPoller(() async {
      throw Exception('boom');
    });
    String? err;
    poller.onError = (e) => err = e;
    poller.start(interval: const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(err, contains('boom'));
    poller.stop();
  });
}
