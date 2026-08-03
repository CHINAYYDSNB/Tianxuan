import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/services/ssh_command_service.dart';
import 'package:tianxuan/services/ssh_monitor.dart';

class MockSsh extends Mock implements SshCommandService {}

void main() {
  late MockSsh ssh;
  late SshMonitor monitor;

  setUp(() {
    ssh = MockSsh();
    monitor = SshMonitor(ssh);
    when(() => ssh.isConnected).thenReturn(true);
  });

  void stubResults(Map<String, String> byCommand) {
    when(() => ssh.execute(any(), timeout: any(named: 'timeout'))).thenAnswer((
      inv,
    ) async {
      final cmd = inv.positionalArguments[0] as String;
      final out = byCommand[cmd] ?? '';
      return SshResult(exitCode: 0, stdout: out);
    });
  }

  test('fetchStatus 解析 top/free/df/uptime/hostname', () async {
    stubResults({
      'top -bn1': '%Cpu(s):  12.5 us,  8.3 sy, 79.2 id,  0.0 wa',
      'free -m':
          '              total        used        free\n'
          'Mem:          16384        4096       12288\n'
          'Swap:          2048           0        2048',
      'df -h':
          'Filesystem      Size  Used Avail Use% Mounted on\n'
          'devtmpfs        8.0G     0  8.0G   0% /dev\n'
          '/dev/sda1        98G   39G   54G  42% /',
      'uptime': ' 16:30:00 up 3 days,  4:05,  1 user,  load average: 0.10',
      'hostname': 'myserver\n',
      'uname -s -r': 'Linux myserver 6.1.0-18-amd64 #1 SMP Debian',
      'cat /proc/cpuinfo | grep "model name" | head -1':
          'model name\t: Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz',
      'cat /proc/cpuinfo | grep -c processor': '8',
      "hostname -I | awk '{print \$1}'": '192.168.1.100',
    });

    final s = await monitor.fetchStatus();
    expect(s.hostname, 'myserver');
    expect(s.cpuUsage, closeTo(20.8, 0.1));
    expect(s.memoryUsage, closeTo(25.0, 0.1));
    expect(s.diskUsage, closeTo(42.0, 0.1));
    expect(s.memoryTotal, contains('16'));
    expect(s.diskTotal, '98G');
    expect(s.cpuCores, 8);
    expect(s.cpuModelName, contains('Intel'));
    expect(s.ipv4Address, '192.168.1.100');
    expect(s.uptimeSeconds, greaterThan(0));
    expect(s.platform, 'Linux');
    expect(s.kernelVersion, contains('6.1'));
  });

  test('内存使用率计算正确', () async {
    stubResults({
      'top -bn1': '%Cpu(s):  0.0 us,  0.0 sy, 100.0 id',
      'free -m':
          '              total        used        free\n'
          'Mem:           8192        2048        6144',
      'df -h':
          'Filesystem  Size  Used Avail Use% Mounted on\n'
          '/dev/sda1        50G   10G   38G  21% /',
      'uptime': 'up 1 day',
      'hostname': 'h',
      'uname -s -r': 'Linux h 5.10.0',
      'cat /proc/cpuinfo | grep "model name" | head -1': '',
      'cat /proc/cpuinfo | grep -c processor': '4',
      "hostname -I | awk '{print \$1}'": '10.0.0.1',
    });
    final s = await monitor.fetchStatus();
    expect(s.memoryUsage, closeTo(25.0, 0.1));
    expect(s.diskUsage, closeTo(21.0, 0.1));
    expect(s.uptimeSeconds, 86400);
  });

  test('SSH 未连接时 isConnected 为 false', () {
    when(() => ssh.isConnected).thenReturn(false);
    expect(monitor.isConnected, isFalse);
  });
}
