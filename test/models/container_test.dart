import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/container.dart';

void main() {
  group('Container model', () {
    test('fromJson 解析字段', () {
      final c = Container.fromJson({
        'containerID': 'abc',
        'name': 'nginx',
        'imageID': 'img1',
        'imageName': 'nginx:latest',
        'createTime': '2026-01-01',
        'state': 'running',
        'runTime': '2 hours',
        'network': ['bridge'],
        'ports': ['80->80'],
        'isFromApp': true,
        'isFromCompose': true,
        'appName': 'app1',
        'appInstallName': 'install1',
        'isPinned': true,
        'description': 'desc',
      });
      expect(c.name, 'nginx');
      expect(c.isFromCompose, isTrue);
      expect(c.isPinned, isTrue);
      expect(c.ports!.length, 1);
    });

    test('stateLabel 各状态', () {
      expect(
        Container(containerID: 'x', name: 'a', state: 'running').stateLabel,
        '运行中',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'exited').stateLabel,
        '已停止',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'paused').stateLabel,
        '已暂停',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'restarting').stateLabel,
        '重启中',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'removing').stateLabel,
        '删除中',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'dead').stateLabel,
        '异常',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'created').stateLabel,
        '已创建',
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'unknown').stateLabel,
        'unknown',
      );
    });

    test('isRunning/isStopped/isPaused', () {
      expect(
        Container(containerID: 'x', name: 'a', state: 'running').isRunning,
        isTrue,
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'exited').isStopped,
        isTrue,
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'stopped').isStopped,
        isTrue,
      );
      expect(
        Container(containerID: 'x', name: 'a', state: 'paused').isPaused,
        isTrue,
      );
    });
  });

  group('ContainerStats', () {
    test('fromJson 解析 + formattedMemory', () {
      final s = ContainerStats.fromJson({
        'cpuPercent': 12.5,
        'memory': 0.5,
        'cache': 1.0,
        'ioRead': 100,
        'ioWrite': 200,
        'networkRX': 300,
        'networkTX': 400,
      });
      expect(s.cpuPercent, 12.5);
      expect(s.formattedMemory, contains('MB'));
    });

    test('formattedMemory GB 格式', () {
      final s = ContainerStats(memory: 1.5);
      expect(s.formattedMemory, contains('GB'));
    });
  });
}
