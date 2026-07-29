import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/file_api.dart';
import '../models/file_item.dart';

/// 文件操作门面。
///
/// UI / Provider 只依赖此抽象，不直接接触 [FileApi]（dartssh2/dio 在 UI 层属红线）。
/// 当前实现走 1Panel API；后续可加入 SSH fallback 实现同一接口。
abstract class FileService {
  Future<FileListResult> list({
    required String path,
    int page = 1,
    int pageSize = 50,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool? showHidden,
    bool? isDetail,
  });

  Future<FileItem> getContent(String path);

  /// 读取文本文件全文（明文），对应 1Panel `/files/content`。
  Future<String> readFile(String path);

  /// 读取文件原始字节（图片预览等），对应 1Panel `/files/download`。
  Future<Uint8List> readFileBytes(String path);

  /// 按行分页读取（大文件用），对应 1Panel `/files/read`
  Future<FileLineResult> readByLine(
    String path, {
    int page = 1,
    int pageSize = 100,
    String type = 'text',
  });

  Future<void> save(String path, String content);

  Future<void> create(
    String path, {
    bool isDir = false,
    int? mode,
    String? content,
  });

  Future<void> rename(String oldName, String newName);

  Future<void> delete(String path, {bool isDir = false});

  Future<void> batchDelete(List<String> paths);

  Future<void> upload(String path, String localFilePath);

  Future<List<int>> download(String path);

  Future<void> changeMode(String path, int mode);

  Future<void> move(List<String> oldPaths, String newPath);

  Future<bool> checkExists(String path);
}

/// 基于 1Panel API 的实现
class ApiFileService implements FileService {
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
  }) => FileApi.getList(
    path: path,
    page: page,
    pageSize: pageSize,
    search: search,
    sortBy: sortBy,
    sortOrder: sortOrder,
    showHidden: showHidden,
    isDetail: isDetail,
  );

  @override
  Future<FileItem> getContent(String path) => FileApi.getContent(path);

  @override
  Future<String> readFile(String path) => FileApi.readFile(path);

  @override
  Future<Uint8List> readFileBytes(String path) => FileApi.readFileBytes(path);

  @override
  Future<FileLineResult> readByLine(
    String path, {
    int page = 1,
    int pageSize = 100,
    String type = 'text',
  }) => FileApi.readByLine(path, page: page, pageSize: pageSize, type: type);

  @override
  Future<void> save(String path, String content) => FileApi.save(path, content);

  @override
  Future<void> create(
    String path, {
    bool isDir = false,
    int? mode,
    String? content,
  }) => FileApi.create(path, isDir: isDir, mode: mode, content: content);

  @override
  Future<void> rename(String oldName, String newName) =>
      FileApi.rename(oldName, newName);

  @override
  Future<void> delete(String path, {bool isDir = false}) =>
      FileApi.delete(path, isDir: isDir);

  @override
  Future<void> batchDelete(List<String> paths) => FileApi.batchDelete(paths);

  @override
  Future<void> upload(String path, String localFilePath) =>
      FileApi.upload(path, localFilePath);

  @override
  Future<List<int>> download(String path) => FileApi.download(path);

  @override
  Future<void> changeMode(String path, int mode) =>
      FileApi.changeMode(path, mode);

  @override
  Future<void> move(List<String> oldPaths, String newPath) =>
      FileApi.move(oldPaths, newPath);

  @override
  Future<bool> checkExists(String path) => FileApi.checkExists(path);
}

/// 单例 provider，便于测试时 override 为 mock
final fileServiceProvider = Provider<FileService>((_) => ApiFileService());
