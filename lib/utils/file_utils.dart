import '../models/file_item.dart';

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
  if (name == 'dockerfile' || name == 'makefile') return true;
  final ext = (file.extension ?? '').toLowerCase();
  return textExtensions.contains(ext);
}

/// 是否为可预览的图片文件。
bool isImageFile(FileItem file) {
  if (file.isDir) return false;
  final name = file.name.toLowerCase();
  final ext = (file.extension ?? '').toLowerCase();
  if (name == 'dockerfile' || name == 'makefile') return false;
  return imageExtensions.contains(ext);
}
