import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloadChannel = MethodChannel('com.tianxuan.app/downloads');

/// 保存文件到本地 (Native)
/// Android → 公共 Downloads/tianxuan/（文件管理器可见）
/// 其他平台 → 应用文档目录下的 tianxuan/ 子目录
Future<String> saveFile(String name, List<int> bytes) async {
  if (Platform.isAndroid) {
    try {
      final path = await _downloadChannel.invokeMethod<String>(
        'saveToDownloads',
        {'name': name, 'bytes': Uint8List.fromList(bytes)},
      );
      if (path != null && path.isNotEmpty) return path;
    } catch (_) {
      // MediaStore 失败时回退到应用目录
    }
  }
  final dir = await getApplicationDocumentsDirectory();
  final target = Directory('${dir.path}/tianxuan');
  if (!await target.exists()) await target.create(recursive: true);
  final path = '${target.path}/$name';
  final file = File(path);
  await file.writeAsBytes(bytes);
  return path;
}

Future<String> saveTextFile(String name, String text) async {
  return saveFile(name, utf8.encode(text));
}
