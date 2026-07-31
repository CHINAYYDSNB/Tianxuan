import '../models/file_item.dart';

/// 文件在列表中被点击时的打开方式
enum FileOpenMode { edit, preview, download }

/// 根据扩展名判断文件被点击时的打开方式。
/// 文本类（可在线编辑）→ [FileOpenMode.edit]；
/// 图片类（可预览）→ [FileOpenMode.preview]；
/// 其余统一走下载 → [FileOpenMode.download]。
FileOpenMode getFileOpenMode(String extension) {
  final ext = extension.toLowerCase();
  final dotless = ext.startsWith('.') ? ext.substring(1) : ext;
  const editExtensions = {
    'txt',
    'conf',
    'yaml',
    'yml',
    'json',
    'md',
    'sh',
    'log',
    // 运维常见文本格式
    'ini',
    'cfg',
    'toml',
    'xml',
    'properties',
    'env',
    'vhost',
    'htaccess',
    'nginx',
    'service',
    'socket',
    'mount',
    'swap',
    'target',
    'cron',
    'allow',
    'deny',
    'hosts',
  };
  const previewExtensions = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'};
  if (editExtensions.contains(dotless)) return FileOpenMode.edit;
  if (previewExtensions.contains(dotless)) return FileOpenMode.preview;
  return FileOpenMode.download;
}

/// 文本类文件扩展名（可在在线编辑器中打开）
const textExtensions = <String>{
  'txt',
  'md',
  'dart',
  'js',
  'ts',
  'py',
  'go',
  'rs',
  'java',
  'c',
  'cpp',
  'h',
  'css',
  'html',
  'json',
  'xml',
  'yaml',
  'yml',
  'toml',
  'ini',
  'cfg',
  'conf',
  'log',
  'sh',
  'bat',
  'env',
  'sql',
  'rb',
  'php',
  'swift',
  'kt',
  'gradle',
  'lock',
  'gitignore',
  'properties',
  'vhost',
  'htaccess',
  'nginx',
  'service',
  'socket',
  'mount',
  'swap',
  'target',
  'cron',
  'allow',
  'deny',
  'hosts',
};

/// 图片类文件扩展名（可进入预览画廊）
const imageExtensions = <String>{
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'wbmp',
};

/// 是否为可在编辑器中打开的文本文件。
/// 目录、超过 10MB、未知扩展名均视为否。
bool isTextFile(FileItem file) {
  if (file.isDir) return false;
  if (file.size > 10 * 1024 * 1024) return false;
  final name = file.name.toLowerCase();
  if (name == 'dockerfile' ||
      name == 'makefile' ||
      name == 'hosts' ||
      name == '.bashrc' ||
      name == '.zshrc' ||
      name == '.profile') {
    return true;
  }
  final raw = (file.extension ?? '').toLowerCase();
  final ext = raw.startsWith('.') ? raw.substring(1) : raw;
  return textExtensions.contains(ext);
}

/// 是否为可预览的图片文件。
bool isImageFile(FileItem file) {
  if (file.isDir) return false;
  final name = file.name.toLowerCase();
  if (name == 'dockerfile' || name == 'makefile') return false;
  final raw = (file.extension ?? '').toLowerCase();
  final ext = raw.startsWith('.') ? raw.substring(1) : raw;
  return imageExtensions.contains(ext);
}
