import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../api/file_api.dart';
import '../../models/file_item.dart';
import '../../providers/file_provider.dart';
import '../../utils/downloader.dart';
import '../../widgets/file_icon.dart';
import 'file_editor_page.dart';

class FileListPage extends ConsumerStatefulWidget {
  final String? initialPath;

  const FileListPage({super.key, this.initialPath});

  @override
  ConsumerState<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends ConsumerState<FileListPage> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  bool _multiSelectMode = false;
  bool _initialPathSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialPath != null && !_initialPathSet) {
      _initialPathSet = true;
      // 延迟到下一帧确保 widget 树已挂载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(currentPathProvider.notifier).state = widget.initialPath!;
        ref.read(fileListProvider.notifier).refresh();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(fileListProvider);
    final path = ref.watch(currentPathProvider);
    final crumbs = ref.watch(breadcrumbProvider);
    final selected = ref.watch(fileSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: '回到概览',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文件...',
                  border: InputBorder.none,
                ),
                onSubmitted: (v) => ref.read(fileListProvider.notifier).setSearch(v),
              )
            : Text(path == '/' ? '文件管理' : path.split('/').last, overflow: TextOverflow.ellipsis),
        actions: [
          if (_multiSelectMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _multiSelectMode = false);
                ref.read(fileSelectionProvider.notifier).clear();
              },
            )
          else ...[
            IconButton(
              icon: Icon(_showSearch ? Icons.search_off : Icons.search),
              onPressed: () => setState(() => _showSearch = !_showSearch),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _handleBulkAction(v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'create_dir', child: Text('新建文件夹')),
                const PopupMenuItem(value: 'upload', child: Text('上传文件')),
                const PopupMenuItem(value: 'go_root', child: Text('回到根目录')),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 面包屑
          _BreadcrumbBar(crumbs: crumbs),
          // 多选模式提示
          if (_multiSelectMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '已选 ${selected.length} 项',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
          // 文件列表
          Expanded(
            child: files.when(
              data: (result) => result.items.isEmpty
                  ? _emptyState(context)
                  : RefreshIndicator(
                      onRefresh: () => ref.read(fileListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: result.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) => _FileListTile(
                          file: result.items[i],
                          multiSelect: _multiSelectMode,
                          selected: selected.contains(result.items[i].path),
                          onTap: () => _onFileTap(result.items[i], path),
                          onLongPress: () => _onFileLongPress(result.items[i]),
                          onToggleSelect: () =>
                              ref.read(fileSelectionProvider.notifier).toggle(result.items[i].path),
                        ),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errorState(context, e),
            ),
          ),
        ],
      ),
      // 多选底部操作栏
      bottomNavigationBar: _multiSelectMode && selected.isNotEmpty
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _actionBtn(Icons.delete, '删除', () => _confirmBatchDelete(selected)),
                  _actionBtn(Icons.drive_file_rename_outline, '批量', () {}),
                ],
              ),
            )
          : null,
      floatingActionButton: _multiSelectMode
          ? null
          : FloatingActionButton.small(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.create_new_folder),
            ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 20),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }

  void _handleBulkAction(String action) {
    switch (action) {
      case 'create_dir':
        _showCreateDialog(context);
        break;
      case 'upload':
        _pickAndUpload();
        break;
      case 'go_root':
        ref.read(currentPathProvider.notifier).state = '/';
        break;
    }
  }

  void _onFileTap(FileItem file, String currentPath) {
    if (_multiSelectMode) {
      ref.read(fileSelectionProvider.notifier).toggle(file.path);
      return;
    }
    if (file.isDir) {
      ref.read(currentPathProvider.notifier).state = file.path;
    } else if (_isTextFile(file)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => FileEditorPage(filePath: file.path, fileName: file.name),
      ));
    } else {
      _downloadFile(file);
    }
  }

  void _onFileLongPress(FileItem file) {
    if (!_multiSelectMode) {
      setState(() => _multiSelectMode = true);
      ref.read(fileSelectionProvider.notifier).toggle(file.path);
    }
  }

  bool _isTextFile(FileItem file) {
    if (file.size > 10 * 1024 * 1024) return false; // >10MB skip
    final ext = file.extension?.toLowerCase() ?? '';
    final textExts = [
      'txt', 'md', 'dart', 'js', 'ts', 'py', 'go', 'rs', 'java', 'c', 'cpp', 'h',
      'css', 'html', 'json', 'xml', 'yaml', 'yml', 'toml', 'ini', 'cfg', 'conf',
      'log', 'sh', 'bat', 'env', 'gitignore', 'dockerfile', 'makefile',
      'sql', 'rb', 'php', 'swift', 'kt', 'gradle', 'lock',
    ];
    if (textExts.contains(ext)) return true;
    if (file.name.toLowerCase() == 'dockerfile') return true;
    if (file.name.toLowerCase() == 'makefile') return true;
    return false;
  }

  Future<void> _downloadFile(FileItem file) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('下载 ${file.name}...')),
    );
    try {
      final bytes = await FileApi.download(file.path);
      final result = await saveFile(file.name, bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存: $result (${file.formattedSize})')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUpload() async {
    // file_picker 在 Web 和 Mobile 上工作
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final currentPath = ref.read(currentPathProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传 ${f.name}...')),
      );

      if (f.bytes != null) {
        await FileApi.uploadBytes(currentPath, f.name, f.bytes!);
      } else if (f.path != null) {
        await FileApi.upload(currentPath, f.path!);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.name} 上传成功')),
        );
        ref.read(fileListProvider.notifier).silentRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final parent = ref.read(currentPathProvider);
              Navigator.pop(ctx);
              try {
                await ref.read(fileListProvider.notifier).createItem('$parent/$name', isDir: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已创建 $name')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
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

  Future<void> _confirmBatchDelete(Set<String> paths) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${paths.length} 项？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FileApi.batchDelete(paths.toList());
        ref.read(fileSelectionProvider.notifier).clear();
        setState(() => _multiSelectMode = false);
        ref.read(fileListProvider.notifier).silentRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除 ${paths.length} 项')),
          );
        }
      } catch (e) {
        if (context.mounted) {
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
            Icon(Icons.folder_open, size: 64, color: const Color(0xFFAAB4BF)),
            const SizedBox(height: 12),
            Text('此目录为空', style: const TextStyle(fontSize: 16, color: Color(0xFF686F78))),
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
              Text('$e', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
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
          if (i.isOdd) return const Icon(Icons.chevron_right, size: 16, color: Color(0xFFAAB4BF));
          final idx = i ~/ 2;
          final crumb = crumbs[idx];
          final isLast = idx == crumbs.length - 1;
          return TextButton(
            onPressed: isLast ? null : () => ref.read(currentPathProvider.notifier).state = crumb.path,
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
                color: isLast ? Theme.of(context).colorScheme.primary : const Color(0xFFAAB4BF),
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
      title: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(
        file.isDir ? '' : '${file.formattedSize}  ${_formatTime(file.modTime)}',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: file.isDir
          ? Icon(Icons.chevron_right, size: 18, color: const Color(0xFFAAB4BF))
          : PopupMenuButton<String>(
              onSelected: (v) => _handleFileAction(context, ref, v),
              itemBuilder: (_) => [
                if (_isTextExt(file))
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text('编辑'))),
                const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.drive_file_rename_outline, size: 20), title: Text('重命名'))),
                const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download, size: 20), title: Text('下载'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 20, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)))),
              ],
            ),
      onTap: multiSelect ? onToggleSelect : onTap,
      onLongPress: onLongPress,
    );
  }

  bool _isTextExt(FileItem f) {
    if (f.size > 10 * 1024 * 1024) return false;
    final ext = f.extension?.toLowerCase() ?? '';
    return ['txt', 'md', 'dart', 'js', 'ts', 'py', 'go', 'rs', 'java', 'c', 'cpp', 'h',
            'css', 'html', 'json', 'xml', 'yaml', 'yml', 'toml', 'ini', 'cfg', 'conf',
            'log', 'sh', 'bat', 'env', 'sql', 'rb', 'php', 'swift', 'kt', 'gradle', 'lock',
            'gitignore', 'dockerfile', 'makefile'].contains(ext) ||
           f.name.toLowerCase() == 'dockerfile' ||
           f.name.toLowerCase() == 'makefile';
  }

  void _handleFileAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => FileEditorPage(filePath: file.path, fileName: file.name),
        ));
        break;
      case 'rename':
        _showRenameDialog(context, ref);
        break;
      case 'download':
        break;
      case 'delete':
        _confirmDelete(context, ref);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(fileListProvider.notifier).renameFile(file.path, newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已重命名为 $newName')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('重命名失败: $e'), backgroundColor: Colors.red),
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 ${file.name}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(fileListProvider.notifier).deleteFile(file.path, isDir: file.isDir);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${file.name} 已删除')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
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

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(t));
    } catch (_) {
      return t;
    }
  }
}
