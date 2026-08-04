import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/services/docker_service.dart';
import 'package:tianxuan/services/ssh_command_service.dart';

class MockSsh extends Mock implements SshCommandService {}

void main() {
  late MockSsh ssh;
  late DockerService svc;

  setUp(() {
    ssh = MockSsh();
    svc = DockerService(ssh);
    when(
      () => ssh.execute(any(), timeout: any(named: 'timeout')),
    ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'ok'));
  });

  group('DockerService 命令构建', () {
    test('listContainers 执行 docker ps', () async {
      await svc.listContainers();
      verify(
        () => ssh.execute("docker ps --all --format '{{json .}}'"),
      ).called(1);
    });

    test('operate 执行 docker <op> <name>', () async {
      await svc.operate('nginx', 'restart');
      verify(() => ssh.execute('docker restart nginx')).called(1);
    });

    test('listImages 执行 docker images', () async {
      await svc.listImages();
      verify(
        () => ssh.execute("docker images --format '{{json .}}'"),
      ).called(1);
    });

    test('detectComposeCmd 检测 compose 命令', () async {
      when(
        () => ssh.execute('docker compose version 2>/dev/null'),
      ).thenAnswer((_) async => const SshResult(exitCode: 0, stdout: 'v2'));
      final cmd = await svc.detectComposeCmd();
      expect(cmd, 'docker compose');
    });

    test('isDockerAvailable', () async {
      when(
        () => ssh.execute('docker --version 2>/dev/null'),
      ).thenAnswer((_) async => const SshResult(exitCode: 0));
      expect(await svc.isDockerAvailable(), isTrue);
    });

    test('findComposeFiles 执行 find', () async {
      await svc.findComposeFiles();
      verify(
        () => ssh.execute(
          r'''find / -maxdepth 4 -name "docker-compose.yml" -o -name "compose.yaml" 2>/dev/null | head -50''',
        ),
      ).called(1);
    });

    test('composeOp 执行 up -d', () async {
      await svc.composeOp('/opt/app', 'up');
      verify(
        () => ssh.execute(
          'cd "/opt/app" && docker compose -f "docker-compose.yml" up -d',
        ),
      ).called(1);
    });
  });
}
