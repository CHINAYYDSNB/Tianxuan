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

    test('logsOnce 执行 docker logs', () async {
      await svc.logsOnce('nginx');
      verify(() => ssh.execute('docker logs --tail 200 nginx')).called(1);
    });

    test('stats 执行 docker stats', () async {
      await svc.stats('nginx');
      verify(
        () =>
            ssh.execute("docker stats --no-stream --format '{{json .}}' nginx"),
      ).called(1);
    });

    test('inspect 执行 docker inspect', () async {
      await svc.inspect('nginx');
      verify(() => ssh.execute('docker inspect nginx')).called(1);
    });

    test('removeImage 执行 docker rmi', () async {
      await svc.removeImage('sha256:abc');
      verify(() => ssh.execute('docker rmi  sha256:abc')).called(1);
    });

    test('pruneImages 执行 docker image prune', () async {
      await svc.pruneImages();
      verify(() => ssh.execute('docker image prune  -f')).called(1);
    });

    test('dockerInfo 执行 docker info', () async {
      await svc.dockerInfo();
      verify(
        () => ssh.execute(
          "docker info --format '{{json .}}' 2>/dev/null || echo '{}'",
        ),
      ).called(1);
    });

    test('daemonStatus 执行 systemctl', () async {
      await svc.daemonStatus();
      verify(
        () => ssh.execute(
          'systemctl status docker --no-pager 2>/dev/null || echo "inactive"',
        ),
      ).called(1);
    });

    test('readDaemonJson 读取配置', () async {
      await svc.readDaemonJson();
      verify(
        () =>
            ssh.execute('cat /etc/docker/daemon.json 2>/dev/null || echo "{}"'),
      ).called(1);
    });

    test('pullSync 执行 docker pull', () async {
      await svc.pullSync('nginx');
      verify(
        () => ssh.execute('docker pull nginx', timeout: any(named: 'timeout')),
      ).called(1);
    });

    test('remove 执行 docker rm -f', () async {
      await svc.remove('nginx');
      verify(() => ssh.execute('docker rm -f nginx')).called(1);
    });

    test('rename 执行 docker rename', () async {
      await svc.rename('old', 'new');
      verify(() => ssh.execute('docker rename old new')).called(1);
    });

    test('updateContainer 执行 docker update', () async {
      await svc.updateContainer('nginx', {'restart': 'always'});
      verify(
        () => ssh.execute('docker update --restart=always nginx'),
      ).called(1);
    });

    test('findContainer 执行 docker ps filter', () async {
      await svc.findContainer('nginx');
      verify(
        () => ssh.execute(
          "docker ps --all --filter 'name=nginx' --format '{{json .}}'",
        ),
      ).called(1);
    });

    test('listComposes 执行 compose ls', () async {
      await svc.listComposes();
      verify(
        () => ssh.execute(
          'docker compose ls --format json 2>/dev/null || echo "[]"',
        ),
      ).called(1);
    });

    test('composePs 执行 compose ps', () async {
      await svc.composePs('/opt/app');
      verify(
        () => ssh.execute(
          'cd "/opt/app" && docker compose -f "docker-compose.yml" ps --format json 2>/dev/null || echo "[]"',
        ),
      ).called(1);
    });

    test('checkImageUpdate 执行 manifest inspect', () async {
      await svc.checkImageUpdate('nginx');
      verify(
        () => ssh.execute(
          'docker manifest inspect nginx 2>/dev/null || echo "{}"',
        ),
      ).called(1);
    });

    test('inspectImage 执行 image inspect', () async {
      await svc.inspectImage('nginx');
      verify(() => ssh.execute('docker image inspect nginx')).called(1);
    });

    test('daemonOp 执行 systemctl docker', () async {
      await svc.daemonOp('restart');
      verify(() => ssh.execute('sudo systemctl restart docker')).called(1);
    });

    test('reloadDaemon 执行 reload', () async {
      await svc.reloadDaemon();
      verify(
        () => ssh.execute(
          'sudo systemctl reload docker 2>/dev/null || sudo systemctl restart docker',
        ),
      ).called(1);
    });

    test('writeDaemonJson 写入配置', () async {
      await svc.writeDaemonJson('{"x":1}');
      verify(
        () => ssh.execute(
          "echo '{\"x\":1}' | sudo tee /etc/docker/daemon.json > /dev/null",
        ),
      ).called(1);
    });
  });
}
