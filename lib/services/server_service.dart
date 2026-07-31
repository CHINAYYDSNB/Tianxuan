import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/source/panel/one_panel_adapter.dart';
import '../api/client.dart';
import '../models/container.dart';
import '../models/image.dart';
import '../models/compose.dart';

/// Docker / 主机能力统一入口。UI 层只依赖本服务，不直接接触 Dio / 1Panel 适配器。
class ServerService {
  final OnePanelAdapter _adapter;

  ServerService([OnePanelAdapter? adapter])
    : _adapter = adapter ?? OnePanelAdapter();

  Future<List<Container>> listContainers() => _adapter.listContainers();
  Future<void> operateContainer(String name, String operation) =>
      _adapter.operateContainer(name, operation);
  Future<void> removeContainer(String name, {bool force = true}) =>
      _adapter.removeContainer(name, force: force);
  Future<String> inspectContainer(String id, {String detail = ''}) =>
      _adapter.inspectContainer(id, detail: detail);
  Future<ContainerStats> getContainerStats(String containerId) =>
      _adapter.getContainerStats(containerId);

  Future<List<DockerImage>> listImages() => _adapter.listImages();
  Future<void> pullImage(String name) => _adapter.pullImage(name);
  Future<void> removeImage(String id, {bool force = true}) =>
      _adapter.removeImage(id, force: force);
  Future<void> pruneImages({bool all = false}) =>
      _adapter.pruneImages(all: all);
  Future<bool> hasImageUpdate(String name) => _adapter.hasImageUpdate(name);

  Future<List<ComposeItem>> listComposes() => _adapter.listComposes();
  Future<void> operateCompose(String name, String path, String operation) =>
      _adapter.operateCompose(name, path, operation);

  Future<List<String>> getRegistryMirrors() => _adapter.getRegistryMirrors();
  Future<void> updateRegistryMirrors(List<String> mirrors) =>
      _adapter.updateRegistryMirrors(mirrors);

  Future<Map<String, dynamic>> dockerInfo() => _adapter.dockerInfo();
  Future<String> daemonStatus() => _adapter.daemonStatus();
  Future<void> daemonOp(String op) => _adapter.daemonOp(op);
}

final serverServiceProvider = Provider<ServerService>((ref) => ServerService());

/// Docker 列表页的「是否已连接」判定：1Panel API 已配置即视为可用（不再依赖 SSH）。
final serverConfiguredProvider = Provider<bool>(
  (ref) => ApiClient.instance.serverUrl.isNotEmpty,
);
