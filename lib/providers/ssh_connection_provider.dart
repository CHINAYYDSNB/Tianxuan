import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';

/// Manages SSH command connection lifecycle.
/// Reads saved credentials from storage, auto-connects on build.
class SshConnectionNotifier extends StateNotifier<AsyncValue<SshCommandService?>> {
  SshCommandService? _service;

  SshConnectionNotifier() : super(const AsyncValue.data(null)) {
    _autoConnect();
  }

  SshCommandService? get service => _service;

  Future<void> _autoConnect() async {
    final storage = StorageService.instance;
    final raw = await storage.getSshConnections();
    if (raw == null || raw.isEmpty) return;
    final first = raw.first;
    final config = SshConfig(
      host: first['host']?.toString() ?? '',
      port: int.tryParse(first['port']?.toString() ?? '') ?? 22,
      username: first['username']?.toString() ?? 'root',
      password: first['password']?.toString(),
      privateKey: first['privateKey']?.toString(),
    );
    if (config.host.isEmpty) return;
    await connect(config);
  }

  Future<String?> connect(SshConfig config) async {
    state = const AsyncValue.loading();
    try {
      _service?.disconnect();
      _service = SshCommandService();
      await _service!.connect(config);
      state = AsyncValue.data(_service);
      // Save credentials
      await StorageService.instance.saveSshConnections([config.toJson()]);
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.toString();
    }
  }

  void disconnect() {
    try {
      _service?.disconnect();
    } catch (_) {}
    _service = null;
    state = const AsyncValue.data(null);
  }

  @override
  void dispose() {
    _service?.disconnect();
    super.dispose();
  }
}

final sshConnectionProvider =
    StateNotifierProvider<SshConnectionNotifier, AsyncValue<SshCommandService?>>(
  (ref) => SshConnectionNotifier(),
);

/// Shorthand: the current SshCommandService, or null.
final sshServiceProvider = Provider<SshCommandService?>((ref) {
  return ref.watch(sshConnectionProvider).valueOrNull;
});
