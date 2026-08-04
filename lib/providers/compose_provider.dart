import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/docker_api.dart';
import '../services/docker_service.dart';
import '../services/docker_parser.dart';
import '../models/compose.dart';
import 'ssh_connection_provider.dart';

/// Compose 列表：API First（精确 ComposeInfo），SSH Fallback。
class ComposeListNotifier extends AsyncNotifier<List<ComposeItem>> {
  Timer? _timer;

  @override
  Future<List<ComposeItem>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<List<ComposeItem>> _fetch() async {
    // API 优先：1Panel 精确返回 ComposeInfo（含 workdir/path/containers）
    try {
      return await DockerApi.listComposes();
    } catch (e) {
      // SSH fallback
      final ssh = ref.read(sshServiceProvider);
      if (ssh == null) return [];
      try {
        final svc = DockerService(ssh);
        final result = await svc.listComposes();
        if (result.isSuccess && result.stdout.trim().isNotEmpty) {
          final parsed = DockerParser.parseComposeLs(result.stdout);
          if (parsed.isNotEmpty) return parsed;
        }
        final findResult = await svc.findComposeFiles();
        if (findResult.isSuccess && findResult.stdout.trim().isNotEmpty) {
          return DockerParser.parseFindCompose(findResult.stdout);
        }
        return [];
      } catch (_) {
        return [];
      }
    }
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

  Future<void> operate(String name, String operation, {String? path}) async {
    // API 优先：path 由 API 服务端根据 name 定位
    try {
      await DockerApi.operateCompose(name, path: path, operation: operation);
      await refresh();
      return;
    } catch (_) {}
    // SSH fallback
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    String workdir = path ?? '';
    if (workdir.isEmpty) {
      final findResult = await svc.findComposeFiles();
      if (findResult.isSuccess) {
        for (final line in findResult.stdout.split('\n')) {
          if (line.contains(name)) {
            workdir = line.trim();
            final idx = workdir.lastIndexOf('/');
            if (idx > 0) workdir = workdir.substring(0, idx);
            break;
          }
        }
      }
    }
    if (workdir.isEmpty) return;
    await svc.composeOp(workdir, operation);
    await refresh();
  }
}

final composeListProvider =
    AsyncNotifierProvider<ComposeListNotifier, List<ComposeItem>>(
      ComposeListNotifier.new,
    );
