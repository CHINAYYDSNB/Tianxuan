import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/server_service.dart';
import '../models/compose.dart';

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
    final svc = ref.read(serverServiceProvider);
    return svc.listComposes();
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

  Future<void> operate(String name, String path, String operation) async {
    final svc = ref.read(serverServiceProvider);
    await svc.operateCompose(name, path, operation);
    await refresh();
  }
}

final composeListProvider =
    AsyncNotifierProvider<ComposeListNotifier, List<ComposeItem>>(
      ComposeListNotifier.new,
    );
