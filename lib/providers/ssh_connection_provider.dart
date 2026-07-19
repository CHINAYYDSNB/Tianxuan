import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';

/// Manages SSH connection lifecycle.
/// Auto-connects from saved credentials, falls back to detecting host from 1Panel.
class SshConnectionNotifier extends StateNotifier<AsyncValue<SshCommandService?>> {
  SshCommandService? _service;

  SshConnectionNotifier() : super(const AsyncValue.data(null)) {
    _autoConnect();
  }

  SshCommandService? get service => _service;

  /// Extract host from 1Panel URL (e.g., http://114.66.58.232:25567 → 114.66.58.232)
  static Future<String?> detectServerHost() async {
    final url = await StorageService.instance.getServerUrl();
    if (url == null || url.isEmpty) return null;
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return null;
    }
  }

  Future<void> _autoConnect() async {
    final storage = StorageService.instance;
    final raw = await storage.getSshConnections();

    if (raw != null && raw.isNotEmpty) {
      final first = raw.first;
      final host = first['host']?.toString() ?? '';
      if (host.isNotEmpty) {
        final config = SshConfig(
          host: host,
          port: int.tryParse(first['port']?.toString() ?? '') ?? 22,
          username: first['username']?.toString() ?? 'root',
          password: first['password']?.toString(),
          privateKey: first['privateKey']?.toString(),
        );
        await connect(config);
      }
    }
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

final sshServiceProvider = Provider<SshCommandService?>((ref) {
  return ref.watch(sshConnectionProvider).valueOrNull;
});
