import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../utils/downloader.dart';
import '../../utils/file_utils.dart';
import '../../widgets/file_icon.dart';
import 'file_editor_page.dart';
import 'file_image_preview_page.dart';

/// Standalone page (with Scaffold + AppBar)
class FileListPage extends ConsumerStatefulWidget {
  final String? initialPath;

  /// 工作台内嵌时传入：根目录返回时切回概览 tab（而非 pop 退出）
  /// 独立使用时不传：根目录返回正常退出
  final VoidCallback? onRootBack;

  const FileListPage({super.key, this.initialPath, this.onRootBack});

  @override
  ConsumerState<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends ConsumerState<FileListPage> {
  bool _multiSelect = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSortMenu(BuildContext context) {
    final notifier = ref.read(fileListProvider.notifier);
    final by = notifier.sortBy;
    final order = notifier.sortOrder;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        Widget item(String label, String? value) {
          final selected = by == value;
          return ListTile(
            title: Text(label),
            trailing: selected
                ? Icon(
                    order == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                  )
                : null,
            selected: selected,
            onTap: () {
              // 同一字段再点切换升降序
              final newOrder = selected && order == 'asc' ? 'desc' : 'asc';
              notifier.setSort(value, newOrder);
              Navigator.pop(ctx);
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '排序方式',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              item('按名称排序', 'name'),
              item('按修改日期排序', 'mtime'),
              item('按大小排序', 'size'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 系统返回键：
    //  - 子目录 → 返回上一级文件夹
    //  - 根目录 → 内嵌时切回概览 tab；独立时正常退出
    final currentPath = ref.watch(currentPathProvider);
    final showSearch = ref.watch(fileSearchActiveProvider);
    return PopScope(
      canPop: widget.onRootBack == null && currentPath == '/',
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (currentPath != '/') {
          final crumbs = buildBreadcrumbs(currentPath);
          if (crumbs.length >= 2) {
            final parent = crumbs[crumbs.length - 2].path;
            ref.read(currentPathProvider.notifier).state = parent;
          }
        } else if (widget.onRootBack != null) {
          widget.onRootBack!();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: showSearch
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索文件...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (v) =>
                      ref.read(fileListProvider.notifier).setSearch(v),
                )
              : const Text('文件管理'),
          actions: [
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: '排序',
              onPressed: () => _showSortMenu(context),
            ),
            IconButton(
              icon: Icon(showSearch ? Icons.search_off : Icons.search),
              onPressed: () =>
                  ref.read(fileSearchActiveProvider.notifier).state =
                      !showSearch,
            ),
            if (_multiSelect)
              IconButton(
                icon: const Icon(Icons.checklist, color: Colors.blue),
                tooltip: '退出多选',
                onPressed: () {
                  setState(() => _multiSelect = false);
                  ref.read(fileSelectionProvider.notifier).clear();
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: '多选',
                onPressed: () => setState(() => _multiSelect = true),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.add),
                onSelected: (v) {
                  if (v == 'create_dir') {
                    _showCreateDialog(context);
                  } else if (v == 'upload') {
                    _pickAndUpload();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'create_dir',
                    child: Text('新建文件夹'),
                  ),
                  const PopupMenuItem(value: 'upload', child: Text('上传文件')),
                ],
              ),
            ),
          ],
        ),
        body: FileListBody(
          initialPath: widget.initialPath,
          showSearch: showSearch,
          searchCtrl: _searchCtrl,
          multiSelect: _multiSelect,
          onMultiSelectChanged: (v) => setState(() => _multiSelect = v),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '文件夹名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final parent = ref.read(currentPathProvider.notifier).state;
              Navigator.pop(ctx);
              try {
                final sep = parent.endsWith('/') ? '' : '/';
                await ref
                    .read(fileListProvider.notifier)
                    .createItem('$parent$sep$name', isDir: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已创建 $name')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('创建失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || !mounted) return;
      final path = ref.read(currentPathProvider.notifier).state;
      final filePath = result.files.single.path;
      if (filePath == null) return;
      await ref.read(fileListProvider.notifier).uploadFile(path, filePath);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上传成功')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('上传失败: $e')));
      }
    }
  }
}

/// Embeddable body widget (no Scaffold/AppBar)
class FileListBody extends ConsumerStatefulWidget {
  final String? initialPath;
  final bool showSearch;
  final TextEditingController? searchCtrl;
  final bool multiSelect;
  final ValueChanged<bool>? onMultiSelectChanged;

  const FileListBody({
    super.key,
    this.initialPath,
    this.showSearch = false,
    this.searchCtrl,
    this.multiSelect = false,
    this.onMultiSelectChanged,
  });

  @override
  ConsumerState<FileListBody> createState() => _FileListBodyState();
}

class _FileListBodyState extends ConsumerState<FileListBody> {
  bool _initialPathSet = false;

  bool get _multiSelectMode => widget.multiSelect;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialPath != null && !_initialPathSet) {
      _initialPathSet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentPathProvider.notifier).state = widget.initialPath!;
        ref.read(fileListProvider.notifier).refresh();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(fileListProvider);
    final path = ref.watch(currentPathProvider);
    final crumbs = ref.watch(breadcrumbProvider);
    final selected = ref.watch(fileSelectionProvider);

    return Column(
      children: [
        _BreadcrumbBar(crumbs: crumbs),
        if (_multiSelectMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              '已选 ${selected.length} 项',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        Expanded(
          child: files.when(
            data: (result) => result.items.isEmpty
                ? _emptyState(context)
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(fileListProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: result.items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) => _FileListTile(
                        file: result.items[i],
                        multiSelect: _multiSelectMode,
                        selected: selected.contains(result.items[i].path),
                        onTap: () =>
                            _onFileTap(result.items[i], path, result.items),
                        onLongPress: () =>
                            _onFileLongPress(result.items[i], result.items),
                        onToggleSelect: () => ref
                            .read(fileSelectionProvider.notifier)
                            .toggle(result.items[i].path),
                      ),
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorState(context, e),
          ),
        ),
        if (_multiSelectMode && selected.isNotEmpty)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _actionBtn(
                    Icons.delete,
                    '删除',
                    () => _confirmBatchDelete(selected),
                  ),
                  _actionBtn(Icons.drive_file_rename_outline, '批量', () {}),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _onFileTap(FileItem file, String currentPath, List<FileItem> items) {
    if (_multiSelectMode) {
      ref.read(fileSelectionProvider.notifier).toggle(file.path);
      return;
    }
    if (file.isDir) {
      ref.read(currentPathProvider.notifier).state = file.path;
      return;
    }
    switch (getFileOpenMode(p.extension(file.name))) {
      case FileOpenMode.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FileEditorPage(filePath: file.path, fileName: file.name),
          ),
        ).then((_) => ref.read(fileListProvider.notifier).silentRefresh());
      case FileOpenMode.preview:
        final images = items.where(isImageFile).toList();
        final idx = images.indexOf(file);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileImagePreviewPage(
              images: images,
              initialIndex: idx < 0 ? 0 : idx,
            ),
          ),
        );
      case FileOpenMode.download:
        _downloadFile(file);
    }
  }

  void _onFileLongPress(FileItem file, List<FileItem> items) {
    if (_multiSelectMode) return;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(120, 120, 120, 120),
      items: [
        if (isImageFile(file))
          const PopupMenuItem(
            value: 'preview',
            child: ListTile(
              leading: Icon(Icons.image, size: 20),
              title: Text('预览'),
            ),
          ),
        if (isTextFile(file))
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit, size: 20),
              title: Text('编辑'),
            ),
          ),
        const PopupMenuItem(
          value: 'download',
          child: ListTile(
            leading: Icon(Icons.download, size: 20),
            title: Text('下载'),
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline, size: 20),
            title: Text('重命名'),
          ),
        ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
            leading: Icon(Icons.info_outline, size: 20),
            title: Text('详细信息'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: const ListTile(
            leading: Icon(Icons.delete, size: 20, color: Colors.red),
            title: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    ).then((action) {
      if (action == null) return;
      _handleFileAction(file, items, action);
    });
  }

  void _handleFileAction(FileItem file, List<FileItem> items, String action) {
    switch (action) {
      case 'preview':
        final images = items.where(isImageFile).toList();
        final idx = images.indexOf(file);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FileImagePreviewPage(
              images: images,
              initialIndex: idx < 0 ? 0 : idx,
            ),
          ),
        );
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                FileEditorPage(filePath: file.path, fileName: file.name),
          ),
        ).then((_) => ref.read(fileListProvider.notifier).silentRefresh());
        break;
      case 'download':
        _downloadFile(file);
        break;
      case 'rename':
        _showRenameDialog(context, file);
        break;
      case 'info':
        _showFileInfoDialog(context, file);
        break;
      case 'delete':
        _confirmDelete(context, file);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, FileItem file) {
    final ctrl = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(fileListProvider.notifier)
                    .renameFile(file.path, newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已重命名为 $newName')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('重命名失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FileItem file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${file.name}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(fileListProvider.notifier)
                    .deleteFile(file.path, isDir: file.isDir);
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('${file.name} 已删除')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFileInfoDialog(BuildContext context, FileItem file) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('大小', file.isDir ? '目录' : file.formattedSize),
            _infoRow('路径', file.path),
            _infoRow(
              '权限',
              file.formattedMode.isEmpty ? '-' : file.formattedMode,
            ),
            _infoRow('修改日期', _formatTime(file.modTime)),
            if (file.user != null && file.user!.isNotEmpty)
              _infoRow(
                '所属用户',
                '${file.user}${file.group != null && file.group!.isNotEmpty ? ':${file.group}' : ''}',
              ),
            if (file.isHidden) _infoRow('隐藏', '是'),
            if (file.isSymlink) _infoRow('符号链接', '是'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF686F78)),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _downloadFile(FileItem file) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('下载 ${file.name}...')));
    try {
      final bytes = await ref
          .read(fileListProvider.notifier)
          .downloadFile(file.path);
      final result = await saveFile(file.name, bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存: $result (${file.formattedSize})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmBatchDelete(Set<String> paths) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${paths.length} 项？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(fileListProvider.notifier).batchDelete(paths.toList());
        ref.read(fileSelectionProvider.notifier).clear();
        widget.onMultiSelectChanged?.call(false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已删除 ${paths.length} 项')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _emptyState(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder_open, size: 64, color: Color(0xFFAAB4BF)),
        const SizedBox(height: 12),
        const Text(
          '此目录为空',
          style: TextStyle(fontSize: 16, color: Color(0xFF686F78)),
        ),
      ],
    ),
  );

  Widget _errorState(BuildContext context, Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '$e',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(fileListProvider.notifier).refresh(),
            child: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}

/// 面包屑导航栏
class _BreadcrumbBar extends ConsumerWidget {
  final List<BreadcrumbItem> crumbs;
  const _BreadcrumbBar({required this.crumbs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: List.generate(crumbs.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFFAAB4BF),
            );
          }
          final idx = i ~/ 2;
          final crumb = crumbs[idx];
          final isLast = idx == crumbs.length - 1;
          return TextButton(
            onPressed: isLast
                ? null
                : () =>
                      ref.read(currentPathProvider.notifier).state = crumb.path,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              crumb.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                color: isLast
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFAAB4BF),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 单个文件/目录列表项
class _FileListTile extends ConsumerWidget {
  final FileItem file;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  const _FileListTile({
    required this.file,
    required this.multiSelect,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: multiSelect
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelect())
          : FileIcon(file: file),
      title: Text(
        file.name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        file.isDir ? '' : '${file.formattedSize}  ${_formatTime(file.modTime)}',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: file.isDir
          ? const Icon(Icons.chevron_right, size: 18, color: Color(0xFFAAB4BF))
          : null,
      onTap: multiSelect ? onToggleSelect : onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }
}
