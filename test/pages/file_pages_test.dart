import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:tianxuan/api/file_api.dart';
import 'package:tianxuan/models/file_item.dart';
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
  });

  group('FileListPage 路由', () {
    late MockFileService mock;

    setUp(() {
      mock = MockFileService();
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(
          items: [
            fi('a.dart'), // 文本
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
      expect(find.text('a.dart'), findsWidgets);
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
      await tester.tap(find.text('a.dart'));
      await tester.pumpAndSettle();
      expect(find.byType(FileEditorPage), findsOneWidget);
    });
  });
}
