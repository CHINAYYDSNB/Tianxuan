import 'package:flutter/material.dart';
import '../models/file_item.dart';

/// 根据文件类型返回图标 + 颜色
class FileIcon extends StatelessWidget {
  final FileItem file;

  const FileIcon({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getIcon();
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color, size: 22),
    );
  }

  (IconData, Color) _getIcon() {
    if (file.isSymlink) return (Icons.link, Colors.purple);
    if (file.isDir) return (Icons.folder, Colors.amber);

    final ext = file.extension?.toLowerCase() ?? '';

    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'svg',
      'webp',
      'ico',
    ].contains(ext)) {
      return (Icons.image, Colors.green);
    }
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'].contains(ext)) {
      return (Icons.videocam, Colors.red);
    }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg'].contains(ext)) {
      return (Icons.audiotrack, Colors.deepOrange);
    }
    if (['zip', 'tar', 'gz', 'bz2', 'xz', 'rar', '7z'].contains(ext)) {
      return (Icons.archive, Colors.brown);
    }
    if ([
      'txt',
      'md',
      'log',
      'yaml',
      'yml',
      'toml',
      'ini',
      'cfg',
      'conf',
    ].contains(ext)) {
      return (Icons.description, Colors.blueGrey);
    }
    if ([
      'dart',
      'js',
      'ts',
      'py',
      'java',
      'go',
      'rs',
      'c',
      'cpp',
      'h',
      'css',
      'html',
      'json',
      'xml',
      'sh',
      'bat',
    ].contains(ext)) {
      return (Icons.code, Colors.blue);
    }
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return (Icons.picture_as_pdf, Colors.red.shade700);
    }
    if (['deb', 'rpm', 'apk', 'exe', 'msi', 'dmg'].contains(ext)) {
      return (Icons.build, Colors.grey);
    }
    // 无后缀或未知
    if (ext.isEmpty) return (Icons.insert_drive_file, Colors.grey);
    return (Icons.insert_drive_file, Colors.grey);
  }
}
