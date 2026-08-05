import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/cronjob_api.dart';

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

  group('CronjobItem.fromJson', () {
    test('解析字段', () {
      final item = CronjobItem.fromJson({
        'name': 'backup',
        'type': 'shell',
        'spec': '0 2 * * *',
        'status': true,
        'lastRecordId': 3,
      });
      expect(item.name, 'backup');
      expect(item.type, 'shell');
      expect(item.spec, '0 2 * * *');
      expect(item.isRunning, isTrue);
      expect(item.lastRecordId, 3);
    });

    test('status 字符串解析', () {
      final item = CronjobItem.fromJson({'status': '1'});
      expect(item.isRunning, isTrue);
    });

    test('空数据默认值', () {
      final item = CronjobItem.fromJson({});
      expect(item.name, '');
      expect(item.isRunning, isFalse);
    });
  });

  group('CronjobApi', () {
    test('list 解析 items', () async {
      stub['/api/v2/cronjobs/search'] = {
        'code': 200,
        'data': {
          'items': [
            {'name': 'a', 'type': 'shell', 'spec': '0 2 * * *'},
          ],
        },
      };
      final items = await CronjobApi.list();
      expect(items.length, 1);
      expect(items.first.name, 'a');
    });

    test('createShell 成功', () async {
      stub['/api/v2/cronjobs'] = {'code': 200, 'data': null};
      await CronjobApi.createShell(
        name: 't',
        spec: '0 2 * * *',
        script: 'echo hi',
      );
    });

    test('delete 成功', () async {
      stub['/api/v2/cronjobs/del'] = {'code': 200, 'data': null};
      await CronjobApi.delete('t');
    });

    test('runOnce 成功', () async {
      stub['/api/v2/cronjobs/handle'] = {'code': 200, 'data': null};
      await CronjobApi.runOnce('t');
    });

    test('setStatus 成功', () async {
      stub['/api/v2/cronjobs/status'] = {'code': 200, 'data': null};
      await CronjobApi.setStatus('t', true);
    });

    test('records 解析', () async {
      stub['/api/v2/cronjobs/search/records'] = {
        'code': 200,
        'data': {
          'records': [
            {'id': 1, 'status': 'success'},
          ],
        },
      };
      final records = await CronjobApi.records('t');
      expect(records.length, 1);
      expect(records.first['status'], 'success');
    });

    test('非 200 抛异常', () async {
      stub['/api/v2/cronjobs/search'] = {'code': 500, 'message': 'bad'};
      expect(CronjobApi.list(), throwsA(isA<Exception>()));
    });
  });
}
