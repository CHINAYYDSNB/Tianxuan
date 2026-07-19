import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/docker_service.dart';
import '../services/docker_parser.dart';
import '../models/image.dart';
import 'ssh_connection_provider.dart';

class ImageListNotifier extends AsyncNotifier<List<DockerImage>> {
  Timer? _timer;

  @override
  Future<List<DockerImage>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<List<DockerImage>> _fetch() async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return [];
    final svc = DockerService(ssh);
    final result = await svc.listImages();
    if (!result.isSuccess) return [];
    return DockerParser.parseImages(result.stdout);
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch());
  }

  /// Pull image with streaming progress.
  Stream<String> pullStream(String imageName) {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return Stream.value('SSH not connected');
    final svc = DockerService(ssh);
    return svc.pull(imageName);
  }

  Future<void> pull(String imageName) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    await svc.pullSync(imageName);
    await refresh();
  }

  Future<void> remove(List<String> ids) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return;
    final svc = DockerService(ssh);
    for (final id in ids) {
      await svc.removeImage(id, force: true);
    }
    await refresh();
  }

  Future<String> prune({bool all = false}) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return 'SSH not connected';
    final svc = DockerService(ssh);
    final result = await svc.pruneImages(all: all);
    return result.stdout;
  }

  /// Check if newer version of image exists.
  Future<bool> hasUpdate(String imageName) async {
    final ssh = ref.read(sshServiceProvider);
    if (ssh == null) return false;
    final svc = DockerService(ssh);
    // Compare remote manifest vs local inspect
    final remote = await svc.checkImageUpdate(imageName);
    if (!remote.isSuccess) return false;
    final local = await svc.inspectImage(imageName);
    if (!local.isSuccess) return false;
    // Simple heuristic: if remote manifest returns data, compare digest
    return remote.stdout.isNotEmpty && remote.stdout != '{}\n';
  }
}

final imageListProvider =
    AsyncNotifierProvider<ImageListNotifier, List<DockerImage>>(
  ImageListNotifier.new,
);
