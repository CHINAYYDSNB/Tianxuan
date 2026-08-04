import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/providers/container_log_provider.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class MockSsh extends Mock implements SshCommandService {}

void main() {
  group('ContainerLogState', () {
    test('默认状态', () {
      const s = ContainerLogState();
      expect(s.lines, isEmpty);
      expect(s.isConnected, isFalse);
      expect(s.source, LogSource.ssh);
      expect(s.isPaused, isFalse);
    });

    test('copyWith 更新字段', () {
      const s = ContainerLogState();
      final updated = s.copyWith(
        lines: ['a'],
        isConnected: true,
        source: LogSource.sse,
        isPaused: true,
      );
      expect(updated.lines, ['a']);
      expect(updated.isConnected, isTrue);
      expect(updated.source, LogSource.sse);
      expect(updated.isPaused, isTrue);
    });

    test('copyWith 保留未覆盖字段', () {
      const s = ContainerLogState(lines: ['x'], isConnected: true);
      final updated = s.copyWith(isPaused: true);
      expect(updated.lines, ['x']);
      expect(updated.isConnected, isTrue);
    });
  });

  group('ContainerLogNotifier', () {
    test('clear 清空行', () {
      final ssh = MockSsh();
      when(() => ssh.isConnected).thenReturn(false);
      final n = ContainerLogNotifier('c1', ssh: ssh);
      n.state = n.state.copyWith(lines: ['a', 'b']);
      n.clear();
      expect(n.state.lines, isEmpty);
      n.dispose();
    });

    test('togglePause 切换暂停', () {
      final ssh = MockSsh();
      when(() => ssh.isConnected).thenReturn(false);
      final n = ContainerLogNotifier('c1', ssh: ssh);
      n.togglePause();
      expect(n.state.isPaused, isTrue);
      n.togglePause();
      expect(n.state.isPaused, isFalse);
      n.dispose();
    });

    test('disconnect 置为未连接', () {
      final ssh = MockSsh();
      when(() => ssh.isConnected).thenReturn(false);
      final n = ContainerLogNotifier('c1', ssh: ssh);
      n.state = n.state.copyWith(isConnected: true);
      n.disconnect();
      expect(n.state.isConnected, isFalse);
      n.dispose();
    });
  });
}
