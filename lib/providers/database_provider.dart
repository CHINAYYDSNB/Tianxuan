import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/database_api.dart';
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/ssh_database_service.dart';
import '../services/storage_service.dart';
import 'ssh_connection_provider.dart';

/// 数据库实例列表（本地持久化，密码加密）。
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

  /// 从 1Panel 导入实例（合并去重，保留已存在的凭据）。
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

  /// 拉取远程连接实例并合并（远程实例也持久化，便于 SSH-only 场景）。
  Future<int> importRemote() async {
    final fetched = <DatabaseInstance>[];
    for (final t in const ['mysql', 'mariadb', 'postgresql']) {
      try {
        fetched.addAll(await DatabaseApi.searchRemoteDatabases(type: t));
      } catch (_) {}
    }
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

/// 数据库操作服务：API First, SSH Fallback。
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return FallbackDatabaseService(
    ssh: ssh != null ? SshDatabaseService(ssh) : null,
  );
});

/// 按实例 id 查找实例（供 family provider 使用）。
DatabaseInstance? _findInstance(Ref ref, String id) {
  for (final inst in ref.watch(databaseInstancesProvider)) {
    if (inst.id == id) return inst;
  }
  return null;
}

/// 实例下的数据库列表。
final databaseItemsProvider = FutureProvider.family<List<DatabaseItem>, String>(
  (ref, instanceId) async {
    final inst = _findInstance(ref, instanceId);
    if (inst == null) return const [];
    return ref.read(databaseServiceProvider).searchDatabases(inst);
  },
);

/// 实例运行状态。
final databaseStatusProvider =
    FutureProvider.family<Map<String, String>, String>((ref, instanceId) async {
      final inst = _findInstance(ref, instanceId);
      if (inst == null) return const {};
      return ref.read(databaseServiceProvider).getStatus(inst);
    });

/// 配置文件内容（MySQL/PostgreSQL 通用）。
final databaseConfigFileProvider = FutureProvider.family<String, String>((
  ref,
  instanceId,
) async {
  final inst = _findInstance(ref, instanceId);
  if (inst == null) return '';
  return ref.read(databaseServiceProvider).loadConfigFile(inst);
});

/// Redis 运行状态。
final redisStatusProvider = FutureProvider.family<Map<String, String>, String>((
  ref,
  instanceId,
) async {
  final inst = _findInstance(ref, instanceId);
  if (inst == null) return const {};
  return ref.read(databaseServiceProvider).getRedisStatus(inst);
});

/// Redis 配置。
final redisConfProvider = FutureProvider.family<RedisConfDto, String>((
  ref,
  instanceId,
) async {
  final inst = _findInstance(ref, instanceId);
  if (inst == null) return const RedisConfDto();
  return ref.read(databaseServiceProvider).getRedisConf(inst);
});

/// Redis 持久化配置。
final redisPersistenceProvider =
    FutureProvider.family<RedisPersistenceDto, String>((ref, instanceId) async {
      final inst = _findInstance(ref, instanceId);
      if (inst == null) return const RedisPersistenceDto();
      return ref.read(databaseServiceProvider).getRedisPersistence(inst);
    });
