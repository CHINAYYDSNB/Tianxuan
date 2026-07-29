import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/client.dart';
import '../api/dashboard_api.dart';
import '../services/storage_service.dart';

class SavedServer {
  final String id;
  final String name;
  final String url;

  /// apiKey 在内存中明文可用, 但存储时加密
  String apiKey;

  SavedServer({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  /// URL 显示用
  String get displayUrl => url.replaceFirst('://', '://');
}

final savedServersProvider =
    StateNotifierProvider<SavedServersNotifier, List<SavedServer>>((ref) {
      return SavedServersNotifier();
    });

class SavedServersNotifier extends StateNotifier<List<SavedServer>> {
  SavedServersNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.instance.getServersJson();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = <SavedServer>[];
      for (final e in list) {
        final id = e['id'] as String;
        final apiKey = await StorageService.instance.getServerKey(id) ?? '';
        loaded.add(
          SavedServer(
            id: id,
            name: e['name'] as String? ?? '',
            url: e['url'] as String? ?? '',
            apiKey: apiKey,
          ),
        );
      }
      state = loaded;
    } catch (_) {}
  }

  Future<void> _save() async {
    await StorageService.instance.saveServersJson(
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    // apiKey 单独加密存储
    for (final s in state) {
      await StorageService.instance.saveServerKey(s.id, s.apiKey);
    }
  }

  Future<void> add(SavedServer server) async {
    state = [...state, server];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await StorageService.instance.deleteServerKey(id);
    await _save();
  }

  Future<void> update(SavedServer server) async {
    state = state.map((s) => s.id == server.id ? server : s).toList();
    await _save();
  }

  /// 切换到服务器：保存配置 → 测试连接 → 触发 dashboard 刷新
  Future<String?> switchTo(SavedServer server, {bool test = true}) async {
    try {
      await ApiClient.instance.saveConfig(server.url, server.apiKey);
      if (test) {
        await DashboardApi.getStatus();
      }
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}
