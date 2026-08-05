import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/api/client.dart';
import 'package:tianxuan/api/host_api.dart';

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

  group('DeviceConf.fromJson', () {
    test('解析完整字段', () {
      final conf = DeviceConf.fromJson({
        'dns': ['8.8.8.8', '1.1.1.1'],
        'hosts': [
          {'ip': '127.0.0.1', 'host': 'localhost'},
        ],
        'hostname': 'my-server',
        'timeZone': 'Asia/Shanghai',
        'ntp': 'ntp.aliyun.com',
        'systemTime': '2024-01-01 00:00:00',
        'swapMemoryTotal': 1048576,
        'swapMemoryUsed': 2048,
      });
      expect(conf.dns, ['8.8.8.8', '1.1.1.1']);
      expect(conf.hosts.length, 1);
      expect(conf.hostname, 'my-server');
      expect(conf.timeZone, 'Asia/Shanghai');
      expect(conf.ntp, 'ntp.aliyun.com');
      expect(conf.hasSwap, isTrue);
    });

    test('空数据默认值', () {
      final conf = DeviceConf.fromJson({});
      expect(conf.dns, isEmpty);
      expect(conf.hostname, '');
      expect(conf.hasSwap, isFalse);
    });
  });

  group('HostApi', () {
    test('getDeviceConf 解析 data', () async {
      stub['/api/v2/toolbox/device/conf'] = {
        'code': 200,
        'data': {
          'hostname': 'demo',
          'dns': ['8.8.8.8'],
        },
      };
      final conf = await HostApi.getDeviceConf();
      expect(conf.hostname, 'demo');
      expect(conf.dns, ['8.8.8.8']);
    });

    test('getDeviceConf 非 200 抛异常', () async {
      stub['/api/v2/toolbox/device/conf'] = {'code': 500, 'message': 'bad'};
      expect(HostApi.getDeviceConf(), throwsA(isA<Exception>()));
    });

    test('updateHostname 成功', () async {
      stub['/api/v2/toolbox/device/update/host'] = {'code': 200, 'data': null};
      await HostApi.updateHostname('new-name');
    });

    test('updateDeviceConf 成功', () async {
      stub['/api/v2/toolbox/device/update/conf'] = {'code': 200, 'data': null};
      await HostApi.updateDeviceConf(dns: ['8.8.8.8'], timeZone: 'UTC');
    });

    test('updatePasswd 成功', () async {
      stub['/api/v2/toolbox/device/update/passwd'] = {
        'code': 200,
        'data': null,
      };
      await HostApi.updatePasswd('secret');
    });

    test('updateSwap 成功', () async {
      stub['/api/v2/toolbox/device/update/swap'] = {'code': 200, 'data': null};
      await HostApi.updateSwap(2048);
    });

    test('getTimeZones 解析 zones', () async {
      stub['/api/v2/toolbox/device/zone/options'] = {
        'code': 200,
        'data': {
          'zones': ['Asia/Shanghai', 'UTC'],
        },
      };
      final zones = await HostApi.getTimeZones();
      expect(zones, contains('Asia/Shanghai'));
    });

    test('getSettings 解析', () async {
      stub['/api/v2/settings/search'] = {
        'code': 200,
        'data': {'serverTime': '2024-01-01'},
      };
      final settings = await HostApi.getSettings();
      expect(settings['serverTime'], '2024-01-01');
    });
  });
}
