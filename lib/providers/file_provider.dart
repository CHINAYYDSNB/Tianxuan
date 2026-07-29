import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/client.dart';
import '../api/file_api.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';

/// 当前浏览路径
final currentPathProvider = StateProvider<String>((_) => '/');

/// 文件列表 (依赖 currentPathProvider)
final fileListProvider =
    AsyncNotifierProvider<FileListNotifier, FileListResult>(
      FileListNotifier.new,
    );

class FileListNotifier extends AsyncNotifier<FileListResult> {
  String? _sortBy;
  String? _sortOrder;
  String? _search;

  FileService get _svc => ref.watch(fileServiceProvider);

  @override
  Future<FileListResult> build() async {
    final path = ref.watch(currentPathProvider);
    return _load(path);
  }

  Future<FileListResult> _load(String path) async {
    return _svc.list(
      path: path,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
      search: _search,
    );
  }

  /// 刷新当前目录
  Future<void> refresh() async {
    final path = ref.read(currentPathProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(path));
  }

  /// 静默刷新 (保留旧数据直到成功)
  Future<void> silentRefresh() async {
    try {
      final path = ref.read(currentPathProvider);
      final data = await _load(path);
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// 设置排序
  void setSort(String? by, String? order) {
    _sortBy = by;
    _sortOrder = order;
    refresh();
  }

  /// 设置搜索
  void setSearch(String? s) {
    _search = s?.isEmpty == true ? null : s;
    refresh();
  }

  /// 删除文件后刷新
  Future<void> deleteFile(String path, {bool isDir = false}) async {
    await _svc.delete(path, isDir: isDir);
    await silentRefresh();
  }

  /// 重命名后刷新
  Future<void> renameFile(String oldName, String newName) async {
    await _svc.rename(oldName, newName);
    await silentRefresh();
  }

  /// 创建后刷新
  Future<void> createItem(String path, {bool isDir = false}) async {
    await _svc.create(path, isDir: isDir);
    await silentRefresh();
  }

  /// 上传本地文件到当前目录
  Future<void> uploadFile(String dirPath, String localFilePath) async {
    await _svc.upload(dirPath, localFilePath);
    await silentRefresh();
  }

  /// 下载文件字节
  Future<List<int>> downloadFile(String path) => _svc.download(path);

  /// 批量删除后刷新
  Future<void> batchDelete(List<String> paths) async {
    await _svc.batchDelete(paths);
    await silentRefresh();
  }
}

/// 文件内容 (根据路径加载，整文件)
final fileContentProvider = FutureProvider.family<FileItem, String>((
  ref,
  path,
) async {
  return ref.watch(fileServiceProvider).getContent(path);
});

/// 目录树
final fileTreeProvider = FutureProvider.family<List<FileItem>, String>((
  ref,
  path,
) async {
  final res = await ApiClient.instance.post(
    '/files/tree',
    data: {'path': path},
  );
  final body = res.data;
  if (body is Map && body['data'] is List) {
    return (body['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map((e) => FileItem.fromJson(e))
        .toList();
  }
  return [];
});

/// 面包屑路径
final breadcrumbProvider = Provider<List<BreadcrumbItem>>((ref) {
  final path = ref.watch(currentPathProvider);
  return buildBreadcrumbs(path);
});

/// 由路径构建面包屑（纯函数，便于单测）
List<BreadcrumbItem> buildBreadcrumbs(String path) {
  if (path == '/') return [BreadcrumbItem(name: '/', path: '/')];
  final parts = path.split('/').where((e) => e.isNotEmpty).toList();
  final crumbs = [BreadcrumbItem(name: '/', path: '/')];
  String cur = '';
  for (final part in parts) {
    cur += '/$part';
    crumbs.add(BreadcrumbItem(name: part, path: cur));
  }
  return crumbs;
}

class BreadcrumbItem {
  final String name;
  final String path;
  BreadcrumbItem({required this.name, required this.path});
}

/// 多选: 选中文件路径集合
final fileSelectionProvider =
    StateNotifierProvider<FileSelectionNotifier, Set<String>>(
      (_) => FileSelectionNotifier(),
    );

class FileSelectionNotifier extends StateNotifier<Set<String>> {
  FileSelectionNotifier() : super({});

  void toggle(String path) {
    if (state.contains(path)) {
      final next = Set<String>.from(state);
      next.remove(path);
      state = next;
    } else {
      final next = Set<String>.from(state);
      next.add(path);
      state = next;
    }
  }

  void selectAll(List<String> paths) {
    state = Set.from(paths);
  }

  void clear() => state = {};
}
