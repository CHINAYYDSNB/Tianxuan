import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import '../../services/storage_service.dart';

final desktopServersProvider =
    StateNotifierProvider<DesktopServersNotifier, List<DesktopServer>>(
      (ref) => DesktopServersNotifier(),
    );

final selectedDesktopServerIdProvider = StateProvider<String?>((ref) => null);

class DesktopServersNotifier extends StateNotifier<List<DesktopServer>> {
  DesktopServersNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final storage = StorageService.instance;
    final raw = await storage.getDesktopServersJson();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final loaded = <DesktopServer>[];
      for (final e in list) {
        final id = e['id']?.toString() ?? '';
        final pass = await storage.getDesktopServerPass(id);
        final key = await storage.getDesktopServerKey(id);
        loaded.add(
          DesktopServer.fromJson(e)
            ..password = pass
            ..privateKey = key,
        );
      }
      state = loaded;
    } catch (_) {}
  }

  Future<void> _save() async {
    final storage = StorageService.instance;
    await storage.saveDesktopServersJson(
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    for (final s in state) {
      await storage.saveDesktopServerPass(s.id, s.password);
      await storage.saveDesktopServerKey(s.id, s.privateKey);
    }
  }

  Future<void> add(DesktopServer server) async {
    state = [...state, server];
    await _save();
  }

  Future<void> update(DesktopServer server) async {
    state = state.map((s) => s.id == server.id ? server : s).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    final storage = StorageService.instance;
    await storage.deleteDesktopServerPass(id);
    await storage.deleteDesktopServerKey(id);
    await _save();
  }
}
