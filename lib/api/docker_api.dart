import 'package:dio/dio.dart';
import '../models/compose.dart' as compose;
import '../models/container.dart' as container;
import '../models/image.dart' as image;
import 'client.dart';

/// 1Panel v2 容器/镜像/Compose API 源。
///
/// API First, SSH Fallback — 提供方调用这些方法拉取数据，
/// 失败时由调用方回退到 SSH（DockerService）。
class DockerApi {
  // ─── 容器 ───

  /// POST /containers/search
  static Future<List<container.Container>> listContainers({
    String state = 'all',
    String name = '',
    int page = 1,
    int pageSize = 1000,
  }) async {
    final res = await ApiClient.instance.post(
      '/containers/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'name': name,
        'state': state,
        'orderBy': 'name',
        'order': 'null',
      },
    );
    return _items(
      res,
    ).map((e) => container.Container.fromJson(_asMap(e))).toList();
  }

  /// POST /containers/operate — operation: start|stop|restart|kill|pause|unpause|remove
  static Future<void> operateContainer(String name, String operation) async {
    final res = await ApiClient.instance.post(
      '/containers/operate',
      data: {
        'names': [name],
        'operation': operation,
      },
    );
    _checkCode(res);
  }

  /// GET /containers/stats/:id
  static Future<container.ContainerStats> containerStats(String id) async {
    final res = await ApiClient.instance.get('/containers/stats/$id');
    final data = _dataOf(res);
    return container.ContainerStats.fromJson(_asMap(data));
  }

  // ─── 镜像 ───

  /// POST /containers/image/search
  static Future<List<image.DockerImage>> listImages({
    String name = '',
    int page = 1,
    int pageSize = 1000,
  }) async {
    final res = await ApiClient.instance.post(
      '/containers/image/search',
      data: {
        'page': page,
        'pageSize': pageSize,
        'name': name,
        'orderBy': 'tags',
        'order': 'null',
      },
    );
    return _items(
      res,
    ).map((e) => image.DockerImage.fromJson(_asMap(e))).toList();
  }

  /// POST /containers/image/pull — 注意 1Panel 是异步任务
  static Future<void> pullImages(List<String> imageNames) async {
    final res = await ApiClient.instance.post(
      '/containers/image/pull',
      data: {'imageName': imageNames},
    );
    _checkCode(res);
  }

  /// POST /containers/image/remove — ids: 数据库主键
  static Future<void> removeImages(List<String> ids) async {
    final res = await ApiClient.instance.post(
      '/containers/image/remove',
      data: {'ids': ids.map((e) => int.tryParse(e) ?? 0).toList()},
    );
    _checkCode(res);
  }

  // ─── Compose ───

  /// POST /containers/compose/search — 返回精确的 ComposeInfo
  static Future<List<compose.ComposeItem>> listComposes({
    String info = '',
    int page = 1,
    int pageSize = 1000,
  }) async {
    final res = await ApiClient.instance.post(
      '/containers/compose/search',
      data: {'page': page, 'pageSize': pageSize, 'info': info},
    );
    return _items(
      res,
    ).map((e) => compose.ComposeItem.fromJson(_asMap(e))).toList();
  }

  /// POST /containers/compose/operate — operation: up|start|restart|stop|down|delete|rebuild
  static Future<void> operateCompose(
    String name, {
    String? path,
    required String operation,
  }) async {
    final res = await ApiClient.instance.post(
      '/containers/compose/operate',
      data: {'name': name, 'path': path ?? '', 'operation': operation},
    );
    _checkCode(res);
  }

  // ─── 工具 ───

  static void _checkCode(Response res) {
    final data = res.data;
    if (data is Map && data.containsKey('code') && data['code'] != 200) {
      throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
    }
  }

  static dynamic _dataOf(Response res) {
    final data = res.data;
    if (data is Map) {
      if (data.containsKey('code') && data['code'] != 200) {
        throw Exception(data['message'] ?? '接口返回异常(code=${data['code']})');
      }
      return data['data'];
    }
    return null;
  }

  static List<dynamic> _items(Response res) {
    final data = _dataOf(res);
    if (data is Map && data['items'] is List) {
      return data['items'] as List;
    }
    return const [];
  }

  static Map<String, dynamic> _asMap(dynamic v) {
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }
}
