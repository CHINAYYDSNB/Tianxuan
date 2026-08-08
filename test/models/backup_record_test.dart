import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/backup_record.dart';
import 'package:tianxuan/models/task_log.dart';

void main() {
  group('BackupRecord', () {
    test('fromJson 解析', () {
      final r = BackupRecord.fromJson({
        'id': 1,
        'fileName': 'a.sql',
        'fileDir': '/opt/1panel/backup/database',
        'status': 'success',
        'accountType': 'LOCAL',
        'downloadAccountID': 0,
        'createdAt': '2026-08-08T12:00:00Z',
      });
      expect(r.id, 1);
      expect(r.isSuccess, isTrue);
      expect(r.filePath, '/opt/1panel/backup/database/a.sql');
      expect(r.createdAt, isNotNull);
    });

    test('filePath 处理尾部斜杠', () {
      const r = BackupRecord(
        id: 1,
        fileName: 'a.sql',
        fileDir: '/opt/1panel/backup//',
      );
      expect(r.filePath, '/opt/1panel/backup/a.sql');
    });

    test('copyWith size', () {
      const r = BackupRecord(id: 1, fileName: 'a.sql');
      expect(r.copyWith(size: 123).size, 123);
    });

    test('status 非 success 判定', () {
      const r = BackupRecord(id: 1, fileName: 'a.sql', status: 'failed');
      expect(r.isSuccess, isFalse);
    });
  });

  group('BackupRecordSearchReq', () {
    test('toJson', () {
      const req = BackupRecordSearchReq(
        page: 1,
        pageSize: 10,
        type: 'mysql',
        name: 'mysql',
        detailName: 'appdb',
      );
      final json = req.toJson();
      expect(json['detailName'], 'appdb');
      expect(json['page'], 1);
    });
  });

  group('BackupOption', () {
    test('fromJson', () {
      final o = BackupOption.fromJson({'id': 1, 'type': 'OSS', 'name': 'x'});
      expect(o.type, 'OSS');
      expect(o.id, 1);
    });
  });

  group('TaskLog', () {
    test('fromJson 解析 lines 与执行状态', () {
      final log = TaskLog.fromJson({
        'end': false,
        'taskStatus': 'executing',
        'lines': ['start', 'doing'],
        'totalLines': 2,
      });
      expect(log.isExecuting, isTrue);
      expect(log.lines, ['start', 'doing']);
    });

    test('执行完成判定', () {
      final log = TaskLog.fromJson({'end': true, 'taskStatus': 'done'});
      expect(log.isExecuting, isFalse);
      expect(log.end, isTrue);
    });

    test('lines 空处理', () {
      final log = TaskLog.fromJson({});
      expect(log.lines, isEmpty);
    });
  });

  group('SlowLogFile', () {
    test('fromJson', () {
      final log = SlowLogFile.fromJson({
        'end': true,
        'lines': ['# Time: 2026'],
        'totalLines': 1,
      });
      expect(log.lines.single, contains('Time'));
    });
  });
}
