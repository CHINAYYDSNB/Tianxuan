import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/docker_service.dart';
import '../services/docker_parser.dart';
import '../models/compose.dart';
import 'ssh_connection_provider.dart';

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
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return [];
    final svc = DockerService(ssh);
    // Try docker compose ls first
    final result = await svc.listComposes();
    if (result.isSuccess && result.stdout.trim().isNotEmpty) {
      final parsed = DockerParser.parseComposeLs(result.stdout);
      if (parsed.isNotEmpty) return parsed;
    }
    // Fallback: find compose files
    final findResult = await svc.findComposeFiles();
    if (findResult.isSuccess && findResult.stdout.trim().isNotEmpty) {
      return DockerParser.parseFindCompose(findResult.stdout);
    }
    return [];
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
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    // If no path, try to find it
    String workdir = path ?? '';
    if (workdir.isEmpty) {
      final findResult = await svc.findComposeFiles();
      if (findResult.isSuccess) {
        for (final line in findResult.stdout.split('\n')) {
          if (line.contains(name)) {
            workdir = line.trim();
            // Remove filename to get directory
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
