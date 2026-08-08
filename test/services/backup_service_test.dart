import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/models/backup_record.dart';
import 'package:tianxuan/models/database.dart';
import 'package:tianxuan/services/backup_service.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class _MockSsh extends Mock implements SshCommandService {}

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

const _mysqlApi = DatabaseInstance(
  id: 'a1',
  apiId: 1,
  type: DbType.mysql,
  name: 'mysql',
  username: 'root',
  password: 'secret',
  source: 'api',
  from: 'local',
);

const _manualInst = DatabaseInstance(
  id: 'm1',
  type: DbType.mysql,
  name: 'mysql',
  username: 'root',
  password: 'secret',
  source: 'manual',
  from: 'local',
);

void main() {
  late HttpServer server;
  late Map<String, Object?> stub;
  late _MockSsh ssh;

  setUp(() async {
    HttpOverrides.global = null;
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
    ssh = _MockSsh();
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('ApiBackupService', () {
    final svc = ApiBackupService();

    test('listRecords', () async {
      stub['/api/v2/backups/record/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'fileName': 'a.sql', 'status': 'success'},
          ],
          'total': 1,
        },
      };
      final page = await svc.listRecords(_mysqlApi, 'appdb');
      expect(page.records.first.fileName, 'a.sql');
    });

    test('backup 返回非空 taskID', () async {
      stub['/api/v2/backups/backup'] = {'code': 200, 'data': null};
      final taskID = await svc.backup(_mysqlApi, 'appdb');
      expect(taskID, isNotEmpty);
    });

    test('recover 返回非空 taskID', () async {
      stub['/api/v2/backups/recover'] = {'code': 200, 'data': null};
      const record = BackupRecord(
        id: 1,
        fileName: 'a.sql',
        fileDir: '/opt/backup',
      );
      final taskID = await svc.recover(_mysqlApi, 'appdb', record);
      expect(taskID, isNotEmpty);
    });

    test('账号搜索/创建', () async {
      stub['/api/v2/backups/search'] = {
        'code': 200,
        'data': {'items': [], 'total': 0},
      };
      stub['/api/v2/backups'] = {'code': 200, 'data': null};
      final page = await svc.searchAccounts();
      expect(page.accounts, isEmpty);
      await svc.createAccount({'name': 'x'});
    });

    test('downloadRecord / options / 账号操作', () async {
      stub['/api/v2/backups/record/download'] = {
        'code': 200,
        'data': '/opt/backup/a.sql',
      };
      stub['/api/v2/backups/options'] = {
        'code': 200,
        'data': [
          {'id': 1, 'type': 'LOCAL', 'name': 'local'},
        ],
      };
      stub['/api/v2/backups/update'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/del'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/conn/check'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/buckets'] = {
        'code': 200,
        'data': ['bucket-a'],
      };
      stub['/api/v2/backups/refresh/token'] = {'code': 200, 'data': null};
      stub['/api/v2/backups/local'] = {'code': 200, 'data': '/opt/backup'};

      const record = BackupRecord(
        id: 1,
        fileName: 'a.sql',
        fileDir: '/opt/backup',
      );
      expect(await svc.downloadRecord(record), '/opt/backup/a.sql');
      final options = await svc.loadBackupOptions();
      expect(options.first.type, 'LOCAL');
      await svc.updateAccount({'id': 1});
      await svc.deleteAccount(1);
      await svc.checkConnection({'type': 'OSS'});
      final buckets = await svc.listBuckets({'type': 'OSS'});
      expect(buckets, ['bucket-a']);
      await svc.refreshToken(1);
      expect(await svc.getLocalDir(), '/opt/backup');
    });
  });

  group('SshBackupService', () {
    late SshBackupService svc;

    setUp(() {
      svc = SshBackupService(ssh);
    });

    void okSsh({String stdout = ''}) {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 0, stdout: stdout));
    }

    void failSsh() {
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 1, stderr: 'err'));
    }

    test('listRecords 扫描目录', () async {
      okSsh(stdout: 'a.sql\nb.sql\n');
      final page = await svc.listRecords(_manualInst, 'appdb');
      expect(page.total, 2);
    });

    test('backup 构造 mysqldump 命令', () async {
      okSsh();
      final taskID = await svc.backup(_manualInst, 'appdb');
      expect(taskID, contains('.sql'));
      final calls = verify(
        () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
      ).captured.cast<String>();
      expect(calls.last, contains('mysqldump'));
    });

    test('backup 失败抛异常', () async {
      failSsh();
      expect(svc.backup(_manualInst, 'appdb'), throwsA(isA<Exception>()));
    });

    test('recover 构造恢复命令', () async {
      okSsh();
      const record = BackupRecord(id: 1, fileName: 'a.sql');
      await svc.recover(_manualInst, 'appdb', record);
      final calls = verify(
        () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
      ).captured.cast<String>();
      expect(calls.last, contains('mysql'));
    });

    test('recordSizes 解析 du 输出', () async {
      okSsh(stdout: '1024\t/opt/x/a.sql\n2048\t/opt/x/b.sql\n');
      final sizes = await svc.recordSizes(_manualInst, 'appdb');
      expect(sizes[1], 1024);
      expect(sizes[2], 2048);
    });

    test('deleteRecords 构造 rm 命令', () async {
      okSsh();
      await svc.deleteRecords([3]);
      final calls = verify(
        () => ssh.execute(captureAny(), timeout: any(named: 'timeout')),
      ).captured.cast<String>();
      expect(calls.first, contains('rm -rf'));
    });

    test('downloadRecord 成功/失败', () async {
      okSsh(stdout: 'content');
      const record = BackupRecord(id: 1, fileName: 'a.sql', fileDir: '/d');
      expect(await svc.downloadRecord(record), 'content');

      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 1, stderr: 'err'));
      expect(svc.downloadRecord(record), throwsA(isA<Exception>()));
    });

    test('SSH 账号操作', () async {
      okSsh();
      final options = await svc.loadBackupOptions();
      expect(options.first.type, 'LOCAL');
      final page = await svc.searchAccounts();
      expect(page.accounts, isEmpty);
      expect(await svc.getLocalDir(), '/opt/1panel/.tianxuan-backup');
      final buckets = await svc.listBuckets({});
      expect(buckets, isEmpty);
      await expectLater(svc.createAccount({}), throwsA(isA<Exception>()));
      await expectLater(svc.updateAccount({}), throwsA(isA<Exception>()));
      await expectLater(svc.deleteAccount(1), throwsA(isA<Exception>()));
      await expectLater(svc.checkConnection({}), throwsA(isA<Exception>()));
      await expectLater(svc.refreshToken(1), throwsA(isA<Exception>()));
    });
  });

  group('FallbackBackupService', () {
    test('API 实例走 API', () async {
      stub['/api/v2/backups/record/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'id': 1, 'fileName': 'a.sql', 'status': 'success'},
          ],
          'total': 1,
        },
      };
      final svc = FallbackBackupService(ssh: ssh);
      final page = await svc.listRecords(_mysqlApi, 'appdb');
      expect(page.records.first.fileName, 'a.sql');
    });

    test('API 失败降级 SSH', () async {
      ApiClient.instance.testConfigure('http://127.0.0.1:1', 'k');
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 0, stdout: 'a.sql\n'));
      final svc = FallbackBackupService(ssh: ssh);
      final page = await svc.listRecords(_mysqlApi, 'appdb');
      expect(page.total, 1);
    });

    test('手动实例直接走 SSH', () async {
      ApiClient.instance.testConfigure('http://127.0.0.1:1', 'k');
      when(
        () => ssh.execute(any(), timeout: any(named: 'timeout')),
      ).thenAnswer((_) async => SshResult(exitCode: 0, stdout: 'a.sql\n'));
      final svc = FallbackBackupService(ssh: ssh);
      final page = await svc.listRecords(_manualInst, 'appdb');
      expect(page.total, 1);
    });

    test('无 SSH 时备份抛异常', () async {
      ApiClient.instance.testConfigure('http://127.0.0.1:1', 'k');
      final svc = FallbackBackupService(ssh: null);
      expect(svc.backup(_mysqlApi, 'appdb'), throwsA(isA<Exception>()));
      expect(svc.deleteRecords([1]), throwsA(isA<Exception>()));
    });
  });
}
