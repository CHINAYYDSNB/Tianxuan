import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tianxuan/pages/workspace/server_workspace_page.dart';

void main() {
  group('ServerSettingsTab', () {
    testWidgets('显示服务器设置入口', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ServerSettingsTab()));
      await tester.pumpAndSettle();
      expect(find.text('服务器设置'), findsOneWidget);
      expect(find.text('SSH 连接'), findsOneWidget);
      expect(find.text('连接检测'), findsOneWidget);
      expect(find.text('SSH 终端'), findsOneWidget);
    });
  });

  group('MoreTabPage', () {
    testWidgets('显示更多占位与按钮', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MoreTabPage()));
      await tester.pumpAndSettle();
      expect(find.text('更多'), findsOneWidget);
      expect(find.text('打开功能面板'), findsOneWidget);
    });
  });
}
