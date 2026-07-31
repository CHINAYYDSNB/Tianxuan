/// 1Panel V2 REST 适配器（复制自 Mono-Dash 的 container_api.dart 逻辑）。
///
/// 所有 Docker 相关操作（容器 / 镜像 / Compose / 守护进程 / 镜像源）均通过
/// 1Panel 的 `/api/v2` 接口完成，不再依赖 SSH 执行 docker CLI。UI 层只通过
/// [ServerService] 调用本适配器，不直接接触 Dio。
///
/// 路径已对照真实测试服务器逐一验证（containers/search、image/all、
/// compose/search、docker/status、daemonjson、prune 等均为 200）。
library;

import 'package:dio/dio.dart';

import '../../../api/client.dart';
import '../../../models/container.dart';
import '../../../models/image.dart';
import '../../../models/compose.dart';

class OnePanelAdapter {
  final ApiClient _client;

  OnePanelAdapter([ApiClient? client]) : _client = client ?? ApiClient.instance;

  /// 解析 1Panel 标准响应体 `{code, message, data}`，成功返回 data，否则抛异常。
  T _unwrap<T>(Response response, T Function(dynamic data) mapper) {
    final body = response.data;
    if (body is! Map) {
      throw Exception('响应格式错误: 期望 JSON, 实际 ${body.runtimeType}');
    }
    final code = body['code'];
    if (code != null && code != 200 && code != 0) {
      throw Exception(body['message']?.toString() ?? '接口返回异常(code=$code)');
    }
    final data = body['data'];
    return mapper(data);
  }

  List<T> _toList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ─── Containers ───

  /// 列出容器。
  /// POST /api/v2/containers/search
  Future<List<Container>> listContainers() async {
    final resp = await _client.post(
      '/containers/search',
      data: {
        'page': 1,
        'pageSize': 200,
        'state': 'all',
        'orderBy': 'name',
        'order': 'ascending',
      },
    );
    return _unwrap<List<Container>>(
      resp,
      (data) => _toList(data, Container.fromJson),
    );
  }

  /// 启动 / 停止 / 重启 / 暂停 / 恢复 / 删除容器。
  /// 有效 operation: start / stop / restart / pause / unpause / kill / remove
  /// POST /api/v2/containers/operate  ->  {names:[name], operation}
  Future<void> operateContainer(String name, String operation) async {
    final resp = await _client.post(
      '/containers/operate',
      data: {
        'names': [name],
        'operation': operation,
      },
    );
    _unwrap<void>(resp, (_) => null);
  }

  /// 删除容器（1Panel 通过 operate(operation:'remove') 实现，无独立删除路由）。
  Future<void> removeContainer(String name, {bool force = true}) async {
    await operateContainer(name, 'remove');
  }

  /// 容器详情（原始 docker inspect JSON 字符串）。
  /// POST /api/v2/containers/inspect  ->  {id, type, detail}
  Future<String> inspectContainer(String id, {String detail = ''}) async {
    final resp = await _client.post(
      '/containers/inspect',
      data: {'id': id, 'type': 'container', 'detail': detail},
    );
    return _unwrap<String>(resp, (data) => data?.toString() ?? '');
  }

  /// 容器实时资源统计。
  /// GET /api/v2/containers/stats/{id}
  Future<ContainerStats> getContainerStats(String containerId) async {
    final resp = await _client.get('/containers/stats/$containerId');
    return _unwrap<ContainerStats>(
      resp,
      (data) => data is Map<String, dynamic>
          ? ContainerStats.fromJson(data)
          : ContainerStats(),
    );
  }

  // ─── Images ───

  /// 列出镜像。
  /// GET /api/v2/containers/image/all  ->  直接返回镜像数组
  Future<List<DockerImage>> listImages() async {
    final resp = await _client.get('/containers/image/all');
    return _unwrap<List<DockerImage>>(
      resp,
      (data) => _toList(data, DockerImage.fromJson),
    );
  }

  /// 拉取镜像。
  /// POST /api/v2/containers/image/pull  ->  {imageName: [name]}
  /// 兼容：若服务端期望字符串（旧版 1Panel v2.0.0）则回退为字符串。
  Future<void> pullImage(String name) async {
    final normalized = _normalizeImageName(name);
    try {
      final resp = await _client.post(
        '/containers/image/pull',
        data: {
          'imageName': [normalized],
        },
      );
      _unwrap<void>(resp, (_) => null);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('unmarshal array into Go struct field') ||
          msg.contains('of type string')) {
        final resp = await _client.post(
          '/containers/image/pull',
          data: {'imageName': normalized},
        );
        _unwrap<void>(resp, (_) => null);
      } else {
        rethrow;
      }
    }
  }

  /// 规范化镜像名：去首尾空白、全角冒号转半角、去内部多余空白，
  /// 并把仓库名整体转小写（docker 要求仓库名必须小写，否则报
  /// `repository name (library/X) must be lowercase`）。
  static String _normalizeImageName(String name) {
    return name
        .trim()
        .replaceAll('：', ':') // 全角冒号 -> 半角
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  /// 删除镜像。
  /// POST /api/v2/containers/image/remove  ->  {names:[id], force}
  Future<void> removeImage(String id, {bool force = true}) async {
    final resp = await _client.post(
      '/containers/image/remove',
      data: {
        'names': [id],
        'force': force,
      },
    );
    _unwrap<void>(resp, (_) => null);
  }

  /// 清理悬空 / 全部镜像（通过 prune，pruneType='image'）。
  /// POST /api/v2/containers/prune  ->  {pruneType, withTagAll}
  Future<void> pruneImages({bool all = false}) async {
    final resp = await _client.post(
      '/containers/prune',
      data: {'pruneType': 'image', 'withTagAll': all},
    );
    _unwrap<void>(resp, (_) => null);
  }

  /// 1Panel 不提供「镜像是否有更新」比对接口，暂返回 false。
  Future<bool> hasImageUpdate(String name) async => false;

  // ─── Compose ───

  /// 列出 Compose 项目。
  /// POST /api/v2/containers/compose/search
  Future<List<ComposeItem>> listComposes() async {
    final resp = await _client.post(
      '/containers/compose/search',
      data: {'info': '', 'page': 1, 'pageSize': 200},
    );
    return _unwrap<List<ComposeItem>>(
      resp,
      (data) => _toList(data, ComposeItem.fromJson),
    );
  }

  /// 启动 / 停止 / 重启 / 拉取 Compose 项目。
  /// POST /api/v2/containers/compose/operate
  ///   ->  {name, path, operation, withFile:false, force:false}
  Future<void> operateCompose(
    String name,
    String path,
    String operation,
  ) async {
    final resp = await _client.post(
      '/containers/compose/operate',
      data: {
        'name': name,
        'path': path,
        'operation': operation,
        'withFile': false,
        'force': false,
      },
    );
    _unwrap<void>(resp, (_) => null);
  }

  // ─── Registry Mirrors（镜像源，存于 daemon.json）───

  /// 读取镜像加速源。
  /// GET /api/v2/containers/daemonjson  ->  data.registryMirrors:List<String>
  Future<List<String>> getRegistryMirrors() async {
    try {
      final resp = await _client.get('/containers/daemonjson');
      return _unwrap<List<String>>(resp, (data) {
        if (data is Map) {
          final m = data['registryMirrors'];
          if (m is List) return m.map((e) => e.toString()).toList();
        }
        return <String>[];
      });
    } catch (_) {
      return [];
    }
  }

  /// 保存镜像加速源（按 key 局部更新 daemon.json）。
  /// POST /api/v2/containers/daemonjson/update  ->  {key, value}
  Future<void> updateRegistryMirrors(List<String> mirrors) async {
    final resp = await _client.post(
      '/containers/daemonjson/update',
      data: {'key': 'registryMirrors', 'value': mirrors},
    );
    _unwrap<void>(resp, (_) => null);
  }

  // ─── Docker 守护进程（host 级）───

  /// 读取 Docker 信息（合并 daemon.json 与 docker/status 的真实字段）。
  /// GET /api/v2/containers/daemonjson + GET /api/v2/containers/docker/status
  Future<Map<String, dynamic>> dockerInfo() async {
    try {
      final djResp = await _client.get('/containers/daemonjson');
      final dj = _unwrap<Map<String, dynamic>>(
        djResp,
        (d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{},
      );
      final stResp = await _client.get('/containers/docker/status');
      final st = _unwrap<Map<String, dynamic>>(
        stResp,
        (d) => d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{},
      );
      return {
        'version': dj['version'],
        'cgroupDriver': dj['cgroupDriver'],
        'registryMirrors': dj['registryMirrors'],
        'isSwarm': dj['isSwarm'],
        'liveRestore': dj['liveRestore'],
        'logMaxSize': dj['logMaxSize'],
        'logMaxFile': dj['logMaxFile'],
        'isActive': st['isActive'],
        'isExist': st['isExist'],
      };
    } catch (_) {
      return {};
    }
  }

  /// 守护进程运行状态：running / stopped / unknown。
  Future<String> daemonStatus() async {
    try {
      final resp = await _client.get('/containers/docker/status');
      final d = _unwrap<Map<String, dynamic>>(
        resp,
        (x) => x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{},
      );
      return d['isActive'] == true ? 'running' : 'stopped';
    } catch (_) {
      return 'unknown';
    }
  }

  /// 启动 / 停止 / 重启 Docker 守护进程。
  /// POST /api/v2/containers/docker/operate  ->  {operation}
  Future<void> daemonOp(String op) async {
    final resp = await _client.post(
      '/containers/docker/operate',
      data: {'operation': op},
    );
    _unwrap<void>(resp, (_) => null);
  }
}
