import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tianxuan/api/file_api.dart';
import 'package:tianxuan/models/file_item.dart';
import 'package:tianxuan/providers/file_editor_provider.dart';
import 'package:tianxuan/providers/file_provider.dart';
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
  group('buildBreadcrumbs', () {
    test('根目录', () {
      final c = buildBreadcrumbs('/');
      expect(c.length, 1);
      expect(c.first.name, '/');
    });
    test('多级路径', () {
      final c = buildBreadcrumbs('/a/b/c');
      expect(c.map((e) => e.name).toList(), ['/', 'a', 'b', 'c']);
      expect(c.last.path, '/a/b/c');
    });
  });

  group('FileListNotifier', () {
    late MockFileService mock;
    late ProviderContainer container;

    setUp(() {
      mock = MockFileService();
      container = ProviderContainer(
        overrides: [fileServiceProvider.overrideWithValue(mock)],
      );
    });
    tearDown(() => container.dispose());

    test('加载列表', () async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(
          items: [fi('a.txt'), fi('sub', isDir: true)],
          total: 2,
        ),
      );
      final res = await container.read(fileListProvider.future);
      expect(res.items.length, 2);
      verify(() => mock.list(path: any(named: 'path'))).called(1);
    });

    test('删除后刷新', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      when(
        () => mock.delete(any(), isDir: any(named: 'isDir')),
      ).thenAnswer((_) async {});
      await container
          .read(fileListProvider.notifier)
          .deleteFile('/x/a.txt', isDir: false);
      verify(() => mock.delete('/x/a.txt', isDir: false)).called(1);
    });

    test('重命名后刷新', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      when(() => mock.rename(any(), any())).thenAnswer((_) async {});
      await container
          .read(fileListProvider.notifier)
          .renameFile('/x/old', '/x/new');
      verify(() => mock.rename('/x/old', '/x/new')).called(1);
    });

    test('批量删除', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      when(() => mock.batchDelete(any())).thenAnswer((_) async {});
      await container.read(fileListProvider.notifier).batchDelete([
        '/x/a',
        '/x/b',
      ]);
      verify(() => mock.batchDelete(['/x/a', '/x/b'])).called(1);
    });

    test('上传文件', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      when(() => mock.upload(any(), any())).thenAnswer((_) async {});
      await container
          .read(fileListProvider.notifier)
          .uploadFile('/x', '/local/path.txt');
      verify(() => mock.upload('/x', '/local/path.txt')).called(1);
    });

    test('下载文件字节', () async {
      when(() => mock.download(any())).thenAnswer((_) async => [1, 2, 3]);
      final bytes = await container
          .read(fileListProvider.notifier)
          .downloadFile('/x/a.txt');
      expect(bytes, [1, 2, 3]);
    });
  });

  group('FileListNotifier 额外', () {
    late MockFileService mock;
    late ProviderContainer container;

    setUp(() {
      mock = MockFileService();
      container = ProviderContainer(
        overrides: [fileServiceProvider.overrideWithValue(mock)],
      );
    });
    tearDown(() => container.dispose());

    test('setSort 触发刷新并带参', () async {
      final calls = <Map<Symbol, dynamic>>[];
      when(
        () => mock.list(
          path: any(named: 'path'),
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((inv) {
        calls.add(inv.namedArguments);
        return Future.value(FileListResult(items: [], total: 0));
      });
      container.read(fileListProvider.notifier).setSort('name', 'asc');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        calls.any((m) => m[#sortBy] == 'name' && m[#sortOrder] == 'asc'),
        isTrue,
      );
    });

    test('setSearch 空串触发刷新', () async {
      final calls = <Map<Symbol, dynamic>>[];
      when(
        () => mock.list(
          path: any(named: 'path'),
          sortBy: any(named: 'sortBy'),
          sortOrder: any(named: 'sortOrder'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((inv) {
        calls.add(inv.namedArguments);
        return Future.value(FileListResult(items: [], total: 0));
      });
      container.read(fileListProvider.notifier).setSearch('');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // 初始 build + setSearch 后的刷新，至少两次加载
      expect(calls.length, greaterThanOrEqualTo(2));
    });

    test('createItem 创建后刷新', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => FileListResult(items: [], total: 0));
      when(
        () => mock.create(any(), isDir: any(named: 'isDir')),
      ).thenAnswer((_) async {});
      await container
          .read(fileListProvider.notifier)
          .createItem('/x/new', isDir: true);
      verify(() => mock.create('/x/new', isDir: true)).called(1);
    });

    test('silentRefresh 成功替换数据', () async {
      when(() => mock.list(path: any(named: 'path'))).thenAnswer(
        (_) async => FileListResult(items: [fi('ok.txt')], total: 1),
      );
      await container.read(fileListProvider.notifier).silentRefresh();
      final st = container.read(fileListProvider);
      expect(st.hasValue, isTrue);
      expect(st.value!.items.first.name, 'ok.txt');
    });

    test('silentRefresh 失败且原无数据时报错', () async {
      when(
        () => mock.list(path: any(named: 'path')),
      ).thenAnswer((_) async => throw Exception('network'));
      await container.read(fileListProvider.notifier).silentRefresh();
      expect(container.read(fileListProvider).hasError, isTrue);
    });
  });

  group('FileSelectionNotifier', () {
    test('toggle 增删', () {
      final notifier = FileSelectionNotifier();
      notifier.toggle('/a');
      expect(notifier.state.contains('/a'), isTrue);
      notifier.toggle('/a');
      expect(notifier.state.contains('/a'), isFalse);
    });
    test('selectAll / clear', () {
      final notifier = FileSelectionNotifier();
      notifier.selectAll(['/a', '/b']);
      expect(notifier.state.length, 2);
      notifier.clear();
      expect(notifier.state.isEmpty, isTrue);
    });
  });

  group('FileEditorController', () {
    late MockFileService mock;
    late ProviderContainer container;

    setUp(() {
      mock = MockFileService();
      container = ProviderContainer(
        overrides: [fileServiceProvider.overrideWithValue(mock)],
      );
    });
    tearDown(() => container.dispose());

    FileLineResult page(List<String> lines, bool end, int total) =>
        FileLineResult(
          lines: lines,
          total: lines.length,
          totalLines: total,
          end: end,
          path: '/x/f.txt',
        );

    test('分块加载并聚合', () async {
      when(
        () => mock.readByLine(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((inv) async {
        final p = inv.namedArguments[#page] as int;
        if (p == 1) return page(['line1', 'line2'], false, 3);
        return page(['line3'], true, 3);
      });

      final provider = fileEditorProvider(('/x/f.txt', 'f.txt'));
      container.read(provider.notifier);
      for (var i = 0; i < 100 && container.read(provider).loading; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      final st = container.read(provider);
      expect(st.text, 'line1\nline2\nline3');
      expect(st.totalLines, 3);
      expect(st.fullyLoaded, isTrue);
      expect(st.loading, isFalse);
    });

    test('超大文件未完全加载时标记 fullyLoaded=false', () async {
      // 两页后仍未 end
      when(
        () => mock.readByLine(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((inv) async {
        return page(['x' * 10], false, 99999);
        // 忽略页码，始终未结束；循环会在 _maxPages 后停止
      });
      final provider = fileEditorProvider(('/x/big.txt', 'big.txt'));
      container.read(provider.notifier);
      for (var i = 0; i < 200 && container.read(provider).loading; i++) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
      final st = container.read(provider);
      expect(st.fullyLoaded, isFalse);
    });

    test('保存调用 service', () async {
      when(
        () => mock.readByLine(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => page(['hi'], true, 1));
      when(() => mock.save(any(), any())).thenAnswer((_) async {});

      final provider = fileEditorProvider(('/x/f.txt', 'f.txt'));
      container.read(provider.notifier);
      for (var i = 0; i < 100 && container.read(provider).loading; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await container.read(provider.notifier).save('new content');
      verify(() => mock.save('/x/f.txt', 'new content')).called(1);
      expect(container.read(provider).modified, isFalse);
    });
  });
}
