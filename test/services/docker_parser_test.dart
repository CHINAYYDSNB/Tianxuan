import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/services/docker_parser.dart';

void main() {
  group('DockerParser.parsePs', () {
    test('解析 running 容器', () {
      final jsonl =
          '{"ID":"abc123","Names":"/nginx","Image":"nginx:latest",'
          '"Status":"Up 2 hours","Ports":"0.0.0.0:80->80/tcp","Networks":"bridge","Labels":"com.docker.compose.project=web"}';
      final list = DockerParser.parsePs(jsonl);
      expect(list.length, 1);
      expect(list[0].name, 'nginx');
      expect(list[0].state, 'running');
      expect(list[0].isFromCompose, isTrue);
      expect(list[0].ports!.length, 1);
    });

    test('解析 exited 容器', () {
      final jsonl =
          '{"ID":"def","Names":"/redis","Status":"Exited (0) 1 min ago"}';
      final list = DockerParser.parsePs(jsonl);
      expect(list[0].state, 'exited');
    });

    test('空输入返回空列表', () {
      expect(DockerParser.parsePs(''), isEmpty);
      expect(DockerParser.parsePs('   \n  '), isEmpty);
    });

    test('非法行被跳过', () {
      final list = DockerParser.parsePs('not-json\n{"ID":"x","Names":"/a"}');
      expect(list.length, 1);
      expect(list[0].name, 'a');
    });
  });

  group('DockerParser.parseDockerStats', () {
    test('解析 stats', () {
      final jsonl =
          '{"CPUPerc":"12.50%","MemUsage":"1.02GiB / 8GiB",'
          '"NetIO":"1.5MB / 2.5MB","BlockIO":"10MB / 20MB"}';
      final s = DockerParser.parseDockerStats(jsonl);
      expect(s.cpuPercent, closeTo(12.5, 0.01));
      expect(s.memory, closeTo(1.02, 0.01));
    });

    test('空输入返回默认', () {
      final s = DockerParser.parseDockerStats('');
      expect(s.cpuPercent, 0);
    });
  });

  group('DockerParser.parseImages', () {
    test('解析并合并同 ID 镜像 tag', () {
      final jsonl =
          '{"ID":"sha256:aaa","Repository":"nginx","Tag":"latest","Size":"50MB","Containers":"1","CreatedAt":"2026"}\n'
          '{"ID":"sha256:aaa","Repository":"nginx","Tag":"1.25","Size":"50MB","Containers":"1","CreatedAt":"2026"}';
      final list = DockerParser.parseImages(jsonl);
      expect(list.length, 1);
      expect(list[0].tags.length, 2);
      expect(list[0].size, 50 * 1024 * 1024);
      expect(list[0].isUsed, isTrue);
    });

    test('空输入返回空', () {
      expect(DockerParser.parseImages(''), isEmpty);
    });
  });

  group('DockerParser.parseComposeLs', () {
    test('解析 compose ls JSON 数组', () {
      final json =
          '[{"Name":"web","Status":"running (2)","ConfigFiles":"/opt/web/docker-compose.yml"}]';
      final list = DockerParser.parseComposeLs(json);
      expect(list.length, 1);
      expect(list[0].name, 'web');
      expect(list[0].runningCount, 2);
    });

    test('JSON 数组解析失败回退到 JSONL', () {
      final jsonl = '{"Name":"db","ConfigFiles":"/opt/db/compose.yaml"}';
      final list = DockerParser.parseComposeLs(jsonl);
      expect(list.length, 1);
      expect(list[0].name, 'db');
    });
  });

  group('DockerParser.parseFindCompose', () {
    test('解析 find 输出', () {
      final text = '/opt/app/docker-compose.yml\n/opt/api/compose.yaml';
      final list = DockerParser.parseFindCompose(text);
      expect(list.length, 2);
      expect(list[0].name, 'app');
      expect(list[1].name, 'api');
    });

    test('空输入返回空', () {
      expect(DockerParser.parseFindCompose(''), isEmpty);
    });
  });

  group('DockerParser registry', () {
    test('parseRegistryMirrors', () {
      expect(
        DockerParser.parseRegistryMirrors(
          '{"registry-mirrors":["https://mirror1","https://mirror2"]}',
        ).length,
        2,
      );
      expect(DockerParser.parseRegistryMirrors('{}'), isEmpty);
      expect(DockerParser.parseRegistryMirrors('bad'), isEmpty);
    });

    test('buildDaemonJson', () {
      final json = DockerParser.buildDaemonJson(['https://m']);
      expect(json, contains('registry-mirrors'));
      expect(json, contains('https://m'));
    });
  });

  group('DockerParser.parseDockerInfo', () {
    test('解析 info', () {
      final m = DockerParser.parseDockerInfo('{"ServerVersion":"26.0"}');
      expect(m['ServerVersion'], '26.0');
    });

    test('非法 JSON 返回空', () {
      expect(DockerParser.parseDockerInfo('bad'), isEmpty);
    });
  });
}
