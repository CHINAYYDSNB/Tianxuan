import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import '../../models/file_item.dart';
import '../../services/ssh_command_service.dart';
import '../../services/ssh_file_service.dart';
import '../../theme/app_colors.dart';

/// 桌面 SFTP 文件标签页：路径导航 + 列表 + 拖拽上传/下载。
class FileTab extends ConsumerStatefulWidget {
  final DesktopServer server;
  const FileTab({super.key, required this.server});

  @override
  ConsumerState<FileTab> createState() => _FileTabState();
}

class _FileTabState extends ConsumerState<FileTab> {
  SshCommandService? _ssh;
  SshFileService? _file;
  String _path = '/';
  List<FileItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ssh = SshCommandService();
      await ssh.connect(
        SshConfig(
          host: widget.server.host,
          port: widget.server.port,
          username: widget.server.username,
          password: widget.server.password,
          privateKey: widget.server.privateKey,
        ),
      );
      _ssh = ssh;
      _file = SshFileService(ssh);
      await _load('/');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _load(String path) async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _path = path;
    });
    try {
      final result = await file.list(path: path);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _upload(List<String> localPaths) async {
    final file = _file;
    if (file == null || localPaths.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    for (final localPath in localPaths) {
      try {
        final f = File(localPath);
        final name = f.uri.pathSegments.isNotEmpty
            ? f.uri.pathSegments.last
            : f.path.split(Platform.pathSeparator).last;
        final bytes = await f.readAsBytes();
        await file.uploadBytes('$_path/$name', bytes);
        messenger.showSnackBar(
          SnackBar(
            content: Text('已上传 $name'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
    await _load(_path);
  }

  Future<void> _download(FileItem item) async {
    final file = _file;
    if (file == null || item.isDir) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await file.download(item.path);
      final saveDir = await Directory.systemTemp.createTemp('tianxuan_dl');
      final target = File(
        '${saveDir.path}${Platform.pathSeparator}${item.name}',
      );
      await target.writeAsBytes(bytes);
      messenger.showSnackBar(
        SnackBar(
          content: Text('已下载到 ${target.path}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (details) =>
          _upload(details.files.map((f) => f.path).toList()),
      child: Column(
        children: [
          _toolbar(),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: '上级目录',
            onPressed: _path == '/'
                ? null
                : () {
                    final parts = _path
                        .replaceAll('//', '/')
                        .split('/')
                        .where((s) => s.isNotEmpty)
                        .toList();
                    parts.removeLast();
                    _load('/${parts.join('/')}');
                  },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => _load(_path),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '拖入文件即可上传到当前目录',
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _connect, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final item = _items[i];
        return ListTile(
          dense: true,
          leading: Icon(
            item.isDir ? Icons.folder : _iconFor(item.extension),
            color: item.isDir ? Colors.orange : AppColors.textMuted,
          ),
          title: Text(item.name),
          subtitle: item.isDir ? null : Text(item.formattedSize),
          onTap: item.isDir ? () => _load(item.path) : () => _download(item),
        );
      },
    );
  }

  IconData _iconFor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'go':
      case 'c':
      case 'cpp':
      case 'java':
      case 'sh':
        return Icons.code;
      case 'txt':
      case 'md':
      case 'log':
        return Icons.description;
      case 'zip':
      case 'tar':
      case 'gz':
        return Icons.archive;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  void dispose() {
    _ssh?.disconnect();
    super.dispose();
  }
}
