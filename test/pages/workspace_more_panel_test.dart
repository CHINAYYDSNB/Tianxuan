import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tianxuan/pages/workspace/workspace_more_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('workspace_more_panel 入口管理', () {
    test('kMoreEntries 默认全展示', () {
      expect(kMoreEntries.length, 3);
      expect(
        kMoreEntries.map((e) => e.id),
        containsAll(['ssh', 'scripts', 'database']),
      );
      expect(kMoreEntries.map((e) => e.id).toSet().length, kMoreEntries.length);
      expect(kMoreEntries.every((e) => e.title.isNotEmpty), isTrue);
    });

    test('默认启用全部入口', () async {
      final ids = await loadEnabledMoreIds();
      expect(ids.length, kMoreEntries.length);
    });

    test('保存后能读回自定义状态', () async {
      // 只保留 ssh
      await saveEnabledMoreIds({'ssh'});
      final ids = await loadEnabledMoreIds();
      expect(ids, {'ssh'});
    });

    test('损坏的存储回退到全开', () async {
      final p = await SharedPreferences.getInstance();
      await p.setString('workspace_more_entries_v1', 'not-json');
      final ids = await loadEnabledMoreIds();
      expect(ids.length, kMoreEntries.length);
    });

    test('每个入口有对应可构建页面', () {
      for (final e in kMoreEntries) {
        expect(e.builder, isNotNull);
        expect(e.icon, isNotNull);
      }
    });
  });

  group('更多面板 UI', () {
    testWidgets('弹出面板显示全部入口', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceMorePanel(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // 面板标题 + 全部入口
      expect(find.text('功能'), findsOneWidget);
      for (final e in kMoreEntries) {
        expect(find.text(e.title), findsWidgets);
      }
    });

    testWidgets('编辑模式可勾选/取消并完成', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceMorePanel(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 进入编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // 取消第一个入口（点击其图标）
      final first = kMoreEntries.first;
      await tester.tap(find.byIcon(first.icon).first);
      await tester.pumpAndSettle();

      // 完成
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      // 持久化已更新：第一个入口被禁用
      final ids = await loadEnabledMoreIds();
      expect(ids.contains(first.id), isFalse);
    });
  });
}
