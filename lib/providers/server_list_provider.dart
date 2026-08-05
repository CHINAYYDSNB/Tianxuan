import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/client.dart';
import '../api/dashboard_api.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';

class SavedServer {
  final String id;
  final String name;
  final String url;

  /// apiKey 在内存中明文可用, 但存储时加密
  String apiKey;

  /// 服务器类型: '1panel' 用 API 管理; 'ssh' 纯 SSH 直连（无 API）
  final String type;

  /// SSH 直连凭据（type == 'ssh' 时使用）
  String sshHost;
  int sshPort;
  String sshUsername;
  String? sshPassword;
  String? sshPrivateKey;

  SavedServer({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
    this.type = '1panel',
    this.sshHost = '',
    this.sshPort = 22,
    this.sshUsername = 'root',
    this.sshPassword,
    this.sshPrivateKey,
  });

  bool get isSshOnly => type == 'ssh';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'type': type,
    'sshHost': sshHost,
    'sshPort': sshPort,
    'sshUsername': sshUsername,
  };

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
        final sshPass = await StorageService.instance.getServerSshPass(id);
        final sshKey = await StorageService.instance.getServerSshKey(id);
        loaded.add(
          SavedServer(
            id: id,
            name: e['name'] as String? ?? '',
            url: e['url'] as String? ?? '',
            apiKey: apiKey,
            type: e['type'] as String? ?? '1panel',
            sshHost: e['sshHost'] as String? ?? '',
            sshPort: (e['sshPort'] as num?)?.toInt() ?? 22,
            sshUsername: e['sshUsername'] as String? ?? 'root',
            sshPassword: sshPass,
            sshPrivateKey: sshKey,
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
    // apiKey + SSH 凭据单独加密存储
    for (final s in state) {
      await StorageService.instance.saveServerKey(s.id, s.apiKey);
      await StorageService.instance.saveServerSshPass(s.id, s.sshPassword);
      await StorageService.instance.saveServerSshKey(s.id, s.sshPrivateKey);
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

  /// 切换到服务器：
  /// - 1Panel：保存 API 配置 + 测试连接
  /// - SSH：保存 SSH 配置（连接由调用方处理）
  Future<String?> switchTo(SavedServer server, {bool test = true}) async {
    try {
      if (server.isSshOnly) {
        // 纯 SSH：保存 SSH 连接凭据
        final config = SshConfig(
          host: server.sshHost,
          port: server.sshPort,
          username: server.sshUsername,
          password: server.sshPassword,
          privateKey: server.sshPrivateKey,
        );
        await StorageService.instance.saveSshConnections([config.toJson()]);
        return null;
      }
      // 1Panel：API 配置 + 测试
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
