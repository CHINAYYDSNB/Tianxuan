import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../services/file_service.dart';

/// 将远程图片下载到本地临时文件并缓存（按 path 去重）。
/// PhotoView 需要同步的 ImageProvider，故先落地为 File。
final fileImageProvider = FutureProvider.family<File, String>((
  ref,
  path,
) async {
  final bytes = await ref.watch(fileServiceProvider).download(path);
  final dir = await getTemporaryDirectory();
  final safe = path.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final file = File('${dir.path}/tianxuan_img_$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file;
});
