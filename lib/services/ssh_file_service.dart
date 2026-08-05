import 'dart:convert';
import 'dart:typed_data';

import '../api/file_api.dart';
import '../models/file_item.dart';
import 'file_service.dart';
import 'ssh_command_service.dart';

/// 通过 SSH 命令实现 [FileService] 接口（1Panel API 不可用时的兜底）。
///
/// 遵循 SSH_WRITE_RULES：
/// - 写入使用引号 heredoc `<<'LANXI_EOF'`
/// - 写入前创建时间戳备份
class SshFileService implements FileService {
  final SshCommandService _ssh;

  SshFileService(this._ssh);

  @override
  Future<FileListResult> list({
    required String path,
    int page = 1,
    int pageSize = 50,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? showHidden,
    bool? isDetail,
  }) async {
    final cmd = 'ls -la "$path"';
    final res = await _ssh.execute(cmd);
    if (!res.isSuccess) throw Exception(res.stderr);

    final items = <FileItem>[];
    for (final line in res.stdout.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('total')) continue;
      final file = _parseLsLine(path, trimmed);
      if (file != null) {
        if (search != null && search.isNotEmpty) {
          if (!file.name.toLowerCase().contains(search.toLowerCase())) {
            continue;
          }
        }
        items.add(file);
      }
    }
    return FileListResult(items: items, total: items.length);
  }

  /// 解析 `ls -la` 单行输出
  FileItem? _parseLsLine(String dir, String line) {
    // -rw-r--r-- 1 root root  1234 Jan 1 12:00 filename
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 9) return null;
    final perms = parts[0];
    final name = parts.sublist(8).join(' ');
    if (name == '.' || name == '..') return null;
    final isDir = perms.startsWith('d');
    final isSymlink = perms.startsWith('l');
    final isHidden = name.startsWith('.');
    final size = int.tryParse(parts[4]) ?? 0;
    final modTime = '${parts[5]} ${parts[6]} ${parts[7]}';
    final fullPath = '$dir/${name.trim()}';
    return FileItem(
      name: name,
      path: fullPath,
      isDir: isDir,
      isHidden: isHidden,
      isSymlink: isSymlink,
      size: size,
      modTime: modTime,
      mode: perms,
      user: parts[2],
      group: parts[3],
    );
  }

  @override
  Future<FileItem> getContent(String path) async {
    final res = await _ssh.execute('cat "$path"');
    return FileItem(
      name: _basename(path),
      path: path,
      isDir: false,
      content: res.isSuccess ? res.stdout : null,
    );
  }

  @override
  Future<String> readFile(String path) async {
    final res = await _ssh.execute('cat "$path"');
    if (!res.isSuccess) throw Exception(res.stderr);
    return res.stdout;
  }

  @override
  Future<Uint8List> readFileBytes(String path) async {
    final res = await _ssh.execute('cat "$path"');
    if (!res.isSuccess) throw Exception(res.stderr);
    return Uint8List.fromList(utf8.encode(res.stdout));
  }

  @override
  Future<FileLineResult> readByLine(
    String path, {
    int page = 1,
    int pageSize = 100,
    String type = 'text',
  }) async {
    final content = await readFile(path);
    var lines = content.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }
    return FileLineResult(
      lines: lines,
      total: lines.length,
      totalLines: lines.length,
      end: true,
      path: path,
    );
  }

  @override
  Future<void> save(String path, String content) async {
    // 备份到固定 `.bak`（保存前清理旧备份，单一备份自动覆盖，
    // 避免 `xxx.bak.<timestamp>` 累积且不会被自动清理）
    final backup =
        'rm -f "$path.bak" 2>/dev/null; cp "$path" "$path.bak" 2>/dev/null || true';
    await _ssh.execute(backup);
    final write = 'cat > "$path" <<\'LANXI_EOF\'\n$content\nLANXI_EOF';
    final res = await _ssh.execute(write);
    if (!res.isSuccess) throw Exception(res.stderr);
  }

  @override
  Future<void> create(
    String path, {
    bool isDir = false,
    int? mode,
    String? content,
  }) async {
    String cmd;
    if (isDir) {
      cmd = 'mkdir -p "$path"';
    } else {
      if (content != null) {
        cmd = 'cat > "$path" <<\'LANXI_EOF\'\n$content\nLANXI_EOF';
      } else {
        cmd = 'touch "$path"';
      }
    }
    final res = await _ssh.execute(cmd);
    if (mode != null) {
      await _ssh.execute('chmod $mode "$path"');
    }
    if (!res.isSuccess) throw Exception(res.stderr);
  }

  @override
  Future<void> rename(String oldName, String newName) async {
    final res = await _ssh.execute('mv "$oldName" "$newName"');
    if (!res.isSuccess) throw Exception(res.stderr);
  }

  @override
  Future<void> delete(String path, {bool isDir = false}) async {
    final flag = isDir ? '-rf' : '-f';
    final res = await _ssh.execute('rm $flag "$path"');
    if (!res.isSuccess) throw Exception(res.stderr);
  }

  @override
  Future<void> batchDelete(List<String> paths) async {
    for (final p in paths) {
      await delete(p);
    }
  }

  @override
  Future<void> upload(String path, String localFilePath) async {
    // 通过 cat 读本地文件内容，heredoc 写远程
    // （简化：本地文件内容读取由调用方传入，这里用 readFileBytes 不适用）
    throw UnimplementedError('SSH 上传请使用 uploadBytes');
  }

  /// SSH 版上传：直接写字节内容到远程
  Future<void> uploadBytes(String path, List<int> bytes) async {
    final content = utf8.decode(bytes);
    await save(path, content);
  }

  @override
  Future<List<int>> download(String path) async {
    final res = await _ssh.execute('cat "$path"');
    if (!res.isSuccess) throw Exception(res.stderr);
    return utf8.encode(res.stdout);
  }

  @override
  Future<void> changeMode(String path, int mode) async {
    final res = await _ssh.execute('chmod $mode "$path"');
    if (!res.isSuccess) throw Exception(res.stderr);
  }

  @override
  Future<void> move(List<String> oldPaths, String newPath) async {
    for (final p in oldPaths) {
      final res = await _ssh.execute('mv "$p" "$newPath"');
      if (!res.isSuccess) throw Exception(res.stderr);
    }
  }

  @override
  Future<bool> checkExists(String path) async {
    final res = await _ssh.execute('test -e "$path" && echo yes');
    return res.stdout.trim() == 'yes';
  }

  String _basename(String path) {
    final p = path.replaceAll('\\', '/');
    final idx = p.lastIndexOf('/');
    return idx >= 0 ? p.substring(idx + 1) : p;
  }
}
