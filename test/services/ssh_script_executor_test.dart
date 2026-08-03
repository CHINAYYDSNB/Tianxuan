import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/services/ssh_command_service.dart';
import 'package:tianxuan/services/ssh_script_executor.dart';

class MockSsh extends Mock implements SshCommandService {}

void main() {
  late MockSsh ssh;
  late SshScriptExecutor exec;

  setUp(() {
    ssh = MockSsh();
    exec = SshScriptExecutor(ssh);
    when(() => ssh.isConnected).thenReturn(true);
  });

  test('execute 用 bash 执行并返回输出', () async {
    when(
      () => ssh.execute(any(), timeout: any(named: 'timeout')),
    ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'done'));
    final out = await exec.execute('/opt/scripts/start.sh');
    expect(out, 'done');
    verify(
      () => ssh.execute(
        'bash "/opt/scripts/start.sh" 2>&1',
        timeout: any(named: 'timeout'),
      ),
    ).called(1);
  });

  test('执行失败抛异常', () async {
    when(
      () => ssh.execute(any(), timeout: any(named: 'timeout')),
    ).thenAnswer((_) async => const SshResult(exitCode: 1, stderr: 'boom'));
    expect(
      () => exec.execute('/opt/scripts/bad.sh'),
      throwsA(isA<Exception>()),
    );
  });

  test('isConnected 透传', () {
    expect(exec.isConnected, isTrue);
  });
}
