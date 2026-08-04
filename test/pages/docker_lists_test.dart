import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/models/container.dart' as models;
import 'package:tianxuan/models/compose.dart';
import 'package:tianxuan/models/image.dart';
import 'package:tianxuan/pages/docker/compose_list_page.dart';
import 'package:tianxuan/pages/docker/container_list_page.dart';
import 'package:tianxuan/pages/docker/image_list_page.dart';
import 'package:tianxuan/providers/compose_provider.dart';
import 'package:tianxuan/providers/container_provider.dart';
import 'package:tianxuan/providers/image_provider.dart';

class _ImagesNotifier extends ImageListNotifier {
  @override
  Future<List<DockerImage>> build() async => [
    DockerImage(id: '1', tags: ['nginx:latest'], size: 1024),
  ];
}

class _ContainersNotifier extends ContainerListNotifier {
  @override
  Future<List<models.Container>> build() async => [
    models.Container(containerID: 'a1', name: 'nginx', state: 'running'),
    models.Container(containerID: 'a2', name: 'redis', state: 'exited'),
  ];
}

class _ComposesNotifier extends ComposeListNotifier {
  @override
  Future<List<ComposeItem>> build() async => [
    ComposeItem(name: 'myapp', workdir: '/opt/myapp'),
  ];
}

void main() {
  group('docker 列表页', () {
    testWidgets('容器页渲染列表', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            containerListProvider.overrideWith(_ContainersNotifier.new),
          ],
          child: const MaterialApp(home: ContainerListPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('nginx'), findsOneWidget);
      expect(find.text('redis'), findsOneWidget);
      expect(find.text('运行中'), findsOneWidget);
    });

    testWidgets('镜像页渲染列表', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [imageListProvider.overrideWith(_ImagesNotifier.new)],
          child: const MaterialApp(home: ImageListPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('nginx:latest'), findsWidgets);
    });

    testWidgets('Compose 页渲染列表', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [composeListProvider.overrideWith(_ComposesNotifier.new)],
          child: const MaterialApp(home: ComposeListPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('myapp'), findsOneWidget);
    });
  });
}
