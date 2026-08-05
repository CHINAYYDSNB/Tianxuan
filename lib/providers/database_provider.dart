import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/database_api.dart';
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import 'ssh_connection_provider.dart';

/// 数据库实例列表（本地持久化，密码加密）
class DatabaseInstancesNotifier extends StateNotifier<List<DatabaseInstance>> {
  DatabaseInstancesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final raw = await StorageService.instance.getDatabaseInstancesJson();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = <DatabaseInstance>[];
      for (final e in list) {
        final inst = DatabaseInstance.fromJson(e);
        final pass = await StorageService.instance.getDatabasePass(inst.id);
        loaded.add(inst.copyWith(password: pass));
      }
      state = loaded;
    } catch (_) {}
  }

  Future<void> _save() async {
    await StorageService.instance.saveDatabaseInstancesJson(
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    for (final inst in state) {
      await StorageService.instance.saveDatabasePass(inst.id, inst.password);
    }
  }

  Future<void> add(DatabaseInstance inst) async {
    state = [...state, inst];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await StorageService.instance.saveDatabasePass(id, null);
    await _save();
  }

  Future<void> update(DatabaseInstance inst) async {
    state = state.map((e) => e.id == inst.id ? inst : e).toList();
    await _save();
  }

  /// 从 1Panel 导入实例（合并去重，保留已存在的凭据）
  Future<int> importFromApi() async {
    final fetched = await DatabaseApi.listInstances();
    if (fetched.isEmpty) return 0;
    final existing = <String>{for (final e in state) e.name};
    final added = <DatabaseInstance>[];
    for (final f in fetched) {
      if (existing.contains(f.name)) continue;
      added.add(f);
      existing.add(f.name);
    }
    if (added.isNotEmpty) {
      state = [...state, ...added];
      await _save();
    }
    return added.length;
  }
}

final databaseInstancesProvider =
    StateNotifierProvider<DatabaseInstancesNotifier, List<DatabaseInstance>>(
      (ref) => DatabaseInstancesNotifier(),
    );

/// 数据库操作服务：API First, SSH Fallback
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return FallbackDatabaseService(
    ssh: ssh != null ? SshDatabaseService(ssh) : null,
  );
});
