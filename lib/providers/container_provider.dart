import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/docker_service.dart';
import '../services/docker_parser.dart';
import '../models/container.dart';
import 'ssh_connection_provider.dart';

// ─── Container List ───

class ContainerListNotifier extends AsyncNotifier<List<Container>> {
  Timer? _timer;

  @override
  Future<List<Container>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<List<Container>> _fetch() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return [];
    final svc = DockerService(ssh);
    final result = await svc.listContainers();
    if (!result.isSuccess) return [];
    return DockerParser.parsePs(result.stdout);
  }

  Future<void> _autoRefresh() async {
    try {
      final data = await _fetch();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async {
    try {
      final data = await _fetch();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> operate(String name, String action) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    await svc.operate(name, action);
    await refresh();
  }
}

final containerListProvider =
    AsyncNotifierProvider<ContainerListNotifier, List<Container>>(
  ContainerListNotifier.new,
);

// ─── Container Stats ───

final containerStatsProvider =
    FutureProvider.family<ContainerStats, String>((ref, name) async {
  final ssh = ref.read(sshServiceProvider);
  if (ssh == null) return ContainerStats();
  final svc = DockerService(ssh);
  final result = await svc.stats(name);
  if (!result.isSuccess) return ContainerStats();
  return DockerParser.parseDockerStats(result.stdout);
});

// ─── Container Status Summary ───

final containerStatusProvider = FutureProvider<ContainerStatus>((ref) async {
  final containers = ref.watch(containerListProvider);
  return containers.when(
    data: (list) {
      int count(dynamic s) => list.where((c) => c.state == s).length;
      return ContainerStatus(
        created: count('created'),
        running: count('running'),
        paused: count('paused'),
        restarting: count('restarting'),
        removing: count('removing'),
        exited: count('exited'),
        dead: count('dead'),
        containerCount: list.length,
        imageCount: 0, // computed elsewhere
      );
    },
    loading: () => ContainerStatus(),
    error: (_, __) => ContainerStatus(),
  );
});
