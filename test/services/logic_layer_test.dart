import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/dashboard_api.dart';
import 'package:tianxuan/providers/ssh_connection_provider.dart';
import 'package:tianxuan/services/storage_service.dart';
import 'package:tianxuan/services/src/ssh_service_stub.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late Map<String, Object?> stub;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    stub = {};
    server = await _startServer(stub);
    ApiClient.instance.testConfigure('http://127.0.0.1:${server.port}', 'k');
  });

  tearDown(() async {
    ApiClient.instance.testConfigure('', '');
    await server.close(force: true);
  });

  group('DashboardApi', () {
    test('getStatus 解析状态', () async {
      stub['/api/v2/dashboard/base/0/0'] = {
        'code': 200,
        'data': {'hostname': 'h1', 'cpuUsedPercent': 20},
      };
      final s = await DashboardApi.getStatus();
      expect(s.hostname, 'h1');
    });

    test('code != 200 抛异常', () async {
      stub['/api/v2/dashboard/base/0/0'] = {'code': 500, 'message': 'err'};
      expect(DashboardApi.getStatus(), throwsA(isA<Exception>()));
    });

    test('非 Map 响应抛异常', () async {
      stub['/api/v2/dashboard/base/0/0'] = 'plain text';
      expect(DashboardApi.getStatus(), throwsA(isA<Exception>()));
    });
  });

  group('SshConnectionProvider.detectServerHost', () {
    test('从 URL 提取 host', () async {
      await StorageService.instance.saveServerUrl('http://114.66.58.232:25567');
      expect(await SshConnectionNotifier.detectServerHost(), '114.66.58.232');
    });

    test('无配置返回 null', () async {
      expect(await SshConnectionNotifier.detectServerHost(), isNull);
    });
  });

  group('SshService.buildProxyUrl', () {
    test('返回空串（APK 不用代理）', () {
      expect(SshService.buildProxyUrl('http://x'), '');
    });
  });
}
