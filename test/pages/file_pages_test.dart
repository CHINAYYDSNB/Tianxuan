import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/api/file_api.dart';
import 'package:tianxuan/models/file_item.dart';
import 'package:tianxuan/providers/file_provider.dart';
import 'package:tianxuan/pages/file/file_editor_page.dart';
import 'package:tianxuan/pages/file/file_image_preview_page.dart';
import 'package:tianxuan/pages/file/file_list_page.dart';
import 'package:tianxuan/services/file_service.dart';

class MockFileService extends Mock implements FileService {}

FileItem fi(String name, {bool isDir = false, int size = 0}) => FileItem(
  name: name,
  path: '/x/$name',
  isDir: isDir,
  size: size,
  extension: name.contains('.') ? name.split('.').last : null,
);

void main() {
  group('FileEditorPage', () {
    late MockFileService mock;

    setUp(() {
      mock = MockFileService();
      when(
        () => mock.readByLine(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          type: any(named: 'type'),
        ),
      ).thenAnswer(
        (_) async => FileLineResult(
          lines: ['line1', 'line2'],
          total: 2,
          totalLines: 2,
          end: true,
          path: '/x/f.dart',
        ),
      );
      when(() => mock.save(any(), any())).thenAnswer((_) async {});
    });

    testWidgets('加载内容并渲染 CodeField', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileServiceProvider.overrideWithValue(mock)],
          child: const MaterialApp(
            home: FileEditorPage(filePath: '/x/f.dart', fileName: 'f.dart'),
          ),
        ),
      );
      // 等待异步 load 完成（CodeField 有光标定时器，不能用 pumpAndSettle）
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('f.dart'), findsWidgets); // AppBar 标题
      expect(find.byType(CodeField), findsOneWidget);
      verify(
        () => mock.readByLine(any(), page: 1, pageSize: 200, type: 'text'),
      ).called(1);
    });

    testWidgets('CodeField 配置为多行以支持换行输入', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileServiceProvider.overrideWithValue(mock)],
          child: const MaterialApp(
            home: FileEditorPage(filePath: '/x/f.dart', fileName: 'f.dart'),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final codeField = tester.widget<CodeField>(find.byType(CodeField));
      // maxLines 非 1（这里固定为 999）确保底层 EditableText 推断为 multiline，
      // 不会套用单行过滤器，软键盘回车才能插入换行符 \n。
      expect(codeField.maxLines, 999);
      expect(codeField.minLines, 1);
    });

    testWidgets('编辑后保存调用 service', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileServiceProvider.overrideWithValue(mock)],
          child: const MaterialApp(
            home: FileEditorPage(filePath: '/x/f.dart', fileName: 'f.dart'),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(find.byType(CodeField), 'edited content');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.save));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      verify(() => mock.save('/x/f.dart', 'edited content')).called(1);
    });

    testWidgets('加载失败显示错误与重试', (tester) async {
      when(
        () => mock.readByLine(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) => throw Exception('boom'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileServiceProvider.overrideWithValue(mock)],
          child: const MaterialApp(
            home: FileEditorPage(filePath: '/x/f.dart', fileName: 'f.dart'),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('加载失败'), findsWidgets);
      await tester.tap(find.text('重试'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  group('FileListPage 路由', () {
    late MockFileService mock;

    setUp(() {
      mock = MockFileService();
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(
          items: [
            fi('a.txt'), // 文本
            fi('b.png'), // 图片
            fi('c', isDir: true), // 目录
          ],
          total: 3,
        ),
      );
    });

    Future<void> pumpList(tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fileServiceProvider.overrideWithValue(mock)],
          child: const MaterialApp(home: FileListPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('渲染文件列表', (tester) async {
      await pumpList(tester);
      expect(find.text('a.txt'), findsWidgets);
      expect(find.text('b.png'), findsWidgets);
      expect(find.text('c'), findsWidgets);
    });

    testWidgets('点击图片进入预览页', (tester) async {
      await pumpList(tester);
      await tester.tap(find.text('b.png'));
      await tester.pumpAndSettle();
      expect(find.byType(FileImagePreviewPage), findsOneWidget);
    });

    testWidgets('点击文本进入编辑器', (tester) async {
      await pumpList(tester);
      await tester.tap(find.text('a.txt'));
      await tester.pumpAndSettle();
      expect(find.byType(FileEditorPage), findsOneWidget);
    });
  });

  group('FileListPage 交互', () {
    late MockFileService mock;
    late ProviderContainer container;

    setUp(() {
      mock = MockFileService();
      container = ProviderContainer(
        overrides: [fileServiceProvider.overrideWithValue(mock)],
      );
    });
    tearDown(() => container.dispose());

    Future<void> pumpList(tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: FileListPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('搜索框切换与提交', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('a.dart')], total: 1),
      );
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'query');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    });

    testWidgets('新建文件夹对话框调用 createItem', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('a.dart')], total: 1),
      );
      when(
        () => mock.create(any(), isDir: any(named: 'isDir')),
      ).thenAnswer((_) async {});
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'newdir');
      await tester.pump();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();
      verify(() => mock.create('/newdir', isDir: true)).called(1);
      expect(find.text('已创建 newdir'), findsWidgets);
    });

    testWidgets('点击目录切换当前路径', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('sub', isDir: true)], total: 1),
      );
      await pumpList(tester);
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();
      expect(container.read(currentPathProvider.notifier).state, '/x/sub');
    });

    testWidgets('长按进入多选并批量删除', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(
          items: [fi('a.dart'), fi('b.png'), fi('sub', isDir: true)],
          total: 3,
        ),
      );
      when(() => mock.batchDelete(any())).thenAnswer((_) async {});
      await pumpList(tester);
      await tester.longPress(find.text('a.dart'));
      await tester.pumpAndSettle();
      expect(find.text('已选 1 项'), findsWidgets);
      await tester.tap(find.widgetWithText(InkWell, '删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      verify(() => mock.batchDelete(any())).called(1);
    });

    testWidgets('重命名菜单调用 renameFile', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('a.dart')], total: 1),
      );
      when(() => mock.rename(any(), any())).thenAnswer((_) async {});
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'renamed.dart');
      await tester.pump();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      verify(() => mock.rename('/x/a.dart', 'renamed.dart')).called(1);
    });

    testWidgets('删除菜单调用 deleteFile', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('a.dart')], total: 1),
      );
      when(
        () => mock.delete(any(), isDir: any(named: 'isDir')),
      ).thenAnswer((_) async {});
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      verify(() => mock.delete('/x/a.dart', isDir: false)).called(1);
    });

    testWidgets('下载菜单项为 no-op', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('a.dart')], total: 1),
      );
      await pumpList(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('下载'));
      await tester.pumpAndSettle();
    });

    testWidgets('面包屑点击切换路径', (tester) async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('sub', isDir: true)], total: 1),
      );
      await pumpList(tester);
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();
      expect(container.read(currentPathProvider.notifier).state, '/x/sub');
      await tester.tap(find.widgetWithText(TextButton, '/'));
      await tester.pumpAndSettle();
      expect(container.read(currentPathProvider.notifier).state, '/');
    });

    testWidgets('加载失败显示错误与重试', (tester) async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => throw Exception('boom'));
      await pumpList(tester);
      expect(find.text('加载失败'), findsWidgets);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
    });

    testWidgets('空目录显示空状态', (tester) async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      await pumpList(tester);
      expect(find.text('此目录为空'), findsWidgets);
    });
  });
}
