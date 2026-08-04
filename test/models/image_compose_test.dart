import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/image.dart';
import 'package:tianxuan/models/compose.dart';

void main() {
  group('DockerImage', () {
    test('fromJson + getter', () {
      final img = DockerImage.fromJson({
        'id': 'sha256:abcdef1234567890',
        'createdAt': '2026',
        'isUsed': true,
        'tags': ['nginx:latest'],
        'size': 1024,
        'isPinned': true,
      });
      expect(img.id, 'sha256:abcdef1234567890');
      expect(img.isUsed, isTrue);
      expect(img.tagLabel, 'nginx:latest');
    });

    test('shortId 截取', () {
      final img = DockerImage(id: 'sha256:abcdef1234567890');
      expect(img.shortId, isNot(''));
    });

    test('formattedSize 各种单位', () {
      expect(DockerImage(id: 'x', size: 500).formattedSize, contains('B'));
      expect(DockerImage(id: 'x', size: 2048).formattedSize, contains('KB'));
      expect(
        DockerImage(id: 'x', size: 5 * 1024 * 1024).formattedSize,
        contains('MB'),
      );
      expect(
        DockerImage(id: 'x', size: 2 * 1024 * 1024 * 1024).formattedSize,
        contains('GB'),
      );
    });

    test('tagLabel 空 tag 回退 shortId', () {
      final img = DockerImage(id: 'abc');
      expect(img.tagLabel, 'abc');
    });
  });

  group('ComposeItem', () {
    test('fromJson 解析', () {
      final c = ComposeItem.fromJson({
        'name': 'app',
        'createdAt': '2026',
        'createdBy': 'admin',
        'containerCount': 2,
        'runningCount': 2,
        'configFile': 'docker-compose.yml',
        'workdir': '/opt/app',
        'composeFileExists': true,
        'containers': [
          {'name': 'web', 'state': 'running'},
        ],
      });
      expect(c.name, 'app');
      expect(c.containerCount, 2);
      expect(c.containers.length, 1);
      expect(c.statusLabel, '运行中');
      expect(c.isRunning, isTrue);
    });

    test('statusLabel 部分运行/已停止/空', () {
      final partial = ComposeItem(
        name: 'p',
        containerCount: 2,
        runningCount: 1,
      );
      expect(partial.statusLabel, '部分运行');
      final stopped = ComposeItem(
        name: 's',
        containerCount: 2,
        runningCount: 0,
      );
      expect(stopped.statusLabel, '已停止');
      final empty = ComposeItem(name: 'e', containerCount: 0, runningCount: 0);
      expect(empty.statusLabel, '空');
    });
  });
}
