import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/backup_api.dart';
import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/models/backup_record.dart';

Future<HttpServer> _startServer(Map<String, Object?> stub) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    await req.drain();
    req.response.headers.contentType = ContentType.json;
    req.response.write(
      jsonEncode(stub[req.uri.path] ?? {'code': 200, 'data': {}}),
    );
    await req.response.close();
  });
  return s;
}

void main() {
  late HttpServer server;
  late Map<String, Object?> stub;

  setUp(() async {
    HttpOverrides.global = null;
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  const req = BackupRecordSearchReq(
    page: 1,
    pageSize: 10,
    type: 'mysql',
    name: 'mysql',
    detailName: 'appdb',
  );

  group('BackupApi', () {
    test('searchRecords 解析分页', () async {
      stub['/api/v2/backups/record/search'] = {
        'code': 200,
        'data': {
          'items': [
            {
              'id': 1,
              'fileName': 'appdb_2026.sql',
              'fileDir': '/opt/1panel/backup/database',
              'status': 'success',
              'accountType': 'LOCAL',
              'downloadAccountID': 0,
            },
          ],
          'total': 1,
        },
      };
      final page = await BackupApi.searchRecords(req);
      expect(page.total, 1);
      expect(page.records.first.fileName, 'appdb_2026.sql');
      expect(
        page.records.first.filePath,
        '/opt/1panel/backup/database/appdb_2026.sql',
      );
      expect(page.records.first.isSuccess, isTrue);
    });

    test('recordSizes 解析大小映射', () async {
      stub['/api/v2/backups/record/size'] = {
        'code': 200,
        'data': [
          {'id': 1, 'size': 2048},
        ],
      };
      final sizes = await BackupApi.recordSizes(req);
      expect(sizes[1], 2048);
    });

    test('deleteRecords', () async {
      stub['/api/v2/backups/record/del'] = {'code': 200, 'data': null};
      await BackupApi.deleteRecords([1, 2]);
    });

    test('backupDatabase 返回受理', () async {
      stub['/api/v2/backups/backup'] = {'code': 200, 'data': null};
      await BackupApi.backupDatabase(
        type: 'mysql',
        name: 'mysql',
        detailName: 'appdb',
        secret: '',
        taskID: 'tx-abc',
        description: 'manual',
        args: ['--single-transaction'],
      );
    });

    test('recoverDatabase', () async {
      stub['/api/v2/backups/recover'] = {'code': 200, 'data': null};
      await BackupApi.recoverDatabase(
        downloadAccountID: 0,
        type: 'mysql',
        name: 'mysql',
        detailName: 'appdb',
        file: '/opt/1panel/backup/database/appdb.sql',
        secret: '',
        taskID: 'tx-rec',
      );
    });

    test('downloadRecord 返回服务器路径', () async {
      stub['/api/v2/backups/record/download'] = {
        'code': 200,
        'data': '/opt/1panel/backup/database/appdb.sql',
      };
      final path = await BackupApi.downloadRecord(
        downloadAccountID: 0,
        fileDir: '/opt/1panel/backup',
        fileName: 'appdb.sql',
      );
      expect(path, '/opt/1panel/backup/database/appdb.sql');
    });

    test('账号 CRUD / options / local', () async {
      stub['/api/v2/backups/options'] = {
        'code': 200,
        'data': [
          {'id': 1, 'type': 'LOCAL', 'name': 'local'},
        ],
      };
      stub['/api/v2/backups/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'name': 'ali-oss', 'type': 'OSS'},
          ],
          'total': 1,
        },
      };
      stub['/api/v2/backups'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/update'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/del'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/conn/check'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/buckets'] = {
        'code': 200,
        'data': ['bucket-a'],
      };
      stub['/api/v2/backups/local'] = {
        'code': 200,
        'data': '/opt/1panel/backup',
      };

      final options = await BackupApi.loadBackupOptions();
      expect(options.first.type, 'LOCAL');

      final accounts = await BackupApi.searchAccounts();
      expect(accounts.accounts.first['name'], 'ali-oss');

      await BackupApi.createAccount({'name': 'x'});
      await BackupApi.updateAccount({'id': 1, 'name': 'x'});
      await BackupApi.deleteAccount(1);
      await BackupApi.checkConnection({'type': 'OSS'});
      final buckets = await BackupApi.listBuckets({'type': 'OSS'});
      expect(buckets, ['bucket-a']);
      expect(await BackupApi.getLocalDir(), '/opt/1panel/backup');
    });

    test('非 200 抛异常', () async {
      stub['/api/v2/backups/record/search'] = {
        'code': 500,
        'message': 'server error',
      };
      expect(BackupApi.searchRecords(req), throwsA(isA<Exception>()));
    });
  });
}
