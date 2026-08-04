import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/server_status.dart';

void main() {
  group('ServerStatus.fromJson', () {
    test('解析 flat 格式', () {
      final s = ServerStatus.fromJson({
        'hostname': 'h1',
        'platform': 'linux',
        'cpuUsedPercent': 30,
        'memoryUsedPercent': 50,
        'diskData': [
          {'usedPercent': 60},
        ],
        'timeSinceUptime': '2h',
        'memoryTotal': '8 GiB',
        'memoryUsed': '4 GiB',
        'diskTotal': '100 GiB',
        'diskUsed': '60 GiB',
      });
      expect(s.hostname, 'h1');
      expect(s.cpuUsage, 30);
      expect(s.memoryUsage, 50);
      expect(s.diskUsage, 60);
    });

    test('解析 nested currentInfo 格式', () {
      final s = ServerStatus.fromJson({
        'hostname': 'h2',
        'currentInfo': {'cpuUsedPercent': 10},
        'cpuUsedPercent': 99,
      });
      expect(s.hostname, 'h2');
      expect(s.cpuUsage, 10);
    });

    test('formattedUptime 人类可读', () {
      final s = ServerStatus.fromJson({
        'hostname': '',
        'uptime': 90061,
        'cpuUsedPercent': 0,
        'memoryUsedPercent': 0,
      });
      expect(s.formattedUptime, contains('1天'));
    });

    test('diskData 缺失返回 0', () {
      final s = ServerStatus.fromJson({'hostname': '', 'cpuUsedPercent': 0});
      expect(s.diskUsage, 0);
    });
  });
}
