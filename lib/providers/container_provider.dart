import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/server_service.dart';
import '../models/container.dart';

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
    final svc = ref.read(serverServiceProvider);
    return svc.listContainers();
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
    final svc = ref.read(serverServiceProvider);
    await svc.operateContainer(name, action);
    await refresh();
  }
}

final containerListProvider =
    AsyncNotifierProvider<ContainerListNotifier, List<Container>>(
      ContainerListNotifier.new,
    );

// ─── Container Stats ───

final containerStatsProvider = FutureProvider.family<ContainerStats, String>((
  ref,
  containerId,
) async {
  final svc = ref.read(serverServiceProvider);
  return svc.getContainerStats(containerId);
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
