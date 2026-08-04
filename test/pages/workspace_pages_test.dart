import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/pages/docker/docker_home_page.dart';

void main() {
  group('DockerHomePage', () {
    testWidgets('渲染五个功能入口', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DockerHomePage()));
      await tester.pumpAndSettle();
      expect(find.text('容器'), findsOneWidget);
      expect(find.text('镜像'), findsOneWidget);
      expect(find.text('Compose'), findsOneWidget);
      expect(find.text('镜像站'), findsOneWidget);
      expect(find.text('Docker 管理'), findsOneWidget);
    });
  });
}
