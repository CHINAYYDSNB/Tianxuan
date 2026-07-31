import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/source/ssh_server_source.dart';
import '../models/server_status.dart';
import '../services/ssh_cert_service.dart';
import '../services/ssh_command_service.dart';
import '../services/storage_service.dart';

/// 标记刷新是否出错 (UI 层据此弹 snackbar)
final refreshErrorProvider = StateProvider<String?>((_) => null);

/// 每秒 tick，驱动运行时间实时刷新
final tickProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
});

/// 运行时间实时跳动版（每秒重算）
final tickingUptimeProvider = Provider<String>((ref) {
  final status = ref.watch(serverStatusProvider);
  ref.watch(tickProvider); // 每秒触发 rebuild
  return status.when(
    data: (data) {
      final notifier = ref.read(serverStatusProvider.notifier);
      final elapsed = DateTime.now()
          .difference(notifier.lastFetchTime)
          .inSeconds;
      final total = data.uptimeSeconds + elapsed;
      if (total <= 0) return data.uptime;
      final days = total ~/ 86400;
      final hours = (total % 86400) ~/ 3600;
      final minutes = (total % 3600) ~/ 60;
      final parts = <String>[];
      if (days > 0) parts.add('$days天');
      if (hours > 0) parts.add('$hours小时');
      if (minutes > 0) parts.add('$minutes分');
      parts.add('${total % 60}秒');
      return parts.join(' ');
    },
    loading: () => '加载中...',
    error: (_, __) => '获取失败',
  );
});

class ServerStatusNotifier extends AsyncNotifier<ServerStatus> {
  SshCommandService? _cmd;
  StreamSubscription<void>? _pollSub;
  DateTime _lastFetchTime = DateTime(2000);
  late final AppLifecycleListener _lifecycle;

  @override
  Future<ServerStatus> build() async {
    _lifecycle = AppLifecycleListener(onPause: _pause, onResume: _resume);
    ref.onDispose(() {
      _pollSub?.cancel();
      _lifecycle.dispose();
      _cmd?.disconnect();
      _cmd = null;
    });

    // Stream.periodic 轮询，App 进入后台时暂停、回到前台时恢复。
    _startPolling();
    return _fetchOnce();
  }

  DateTime get lastFetchTime => _lastFetchTime;

  void _startPolling() {
    _pollSub?.cancel();
    _pollSub = Stream.periodic(const Duration(seconds: 2)).listen((_) {
      _poll();
    });
  }

  void _pause() {
    _pollSub?.cancel();
    _pollSub = null;
  }

  void _resume() {
    if (_pollSub == null) {
      _startPolling();
      _poll();
    }
  }

  /// 建立（或复用）到面板主机的 SSH 连接，返回命令执行器。
  Future<SshCommandService> _ensureConnected() async {
    var conns = await StorageService.instance.getSshConnections() ?? [];
    if (conns.isEmpty) {
      final res = await SshCertImporter.importFromCurrentServer();
      if (!res.success) {
        throw Exception(res.reason ?? '未找到可用的 SSH 连接');
      }
      conns = await StorageService.instance.getSshConnections() ?? [];
    }
    if (conns.isEmpty) {
      throw Exception('未找到可用的 SSH 连接');
    }
    // 优先使用「1Panel 主机 (自动)」连接。
    final conn = conns.firstWhere(
      (c) => (c['name']?.toString() ?? '').contains('1Panel'),
      orElse: () => conns.first,
    );
    final cfg = SshConfig(
      host: conn['host']?.toString() ?? 'panel',
      port: int.tryParse(conn['port']?.toString() ?? '22') ?? 22,
      username: conn['username']?.toString() ?? 'root',
      password: conn['password']?.toString(),
      privateKey: conn['privateKey']?.toString(),
    );
    final cmd = SshCommandService();
    await cmd.connect(cfg);
    return cmd;
  }

  Future<ServerStatus> _fetchOnce() async {
    try {
      _cmd ??= await _ensureConnected();
      if (!(_cmd?.isConnected ?? false)) {
        _cmd = await _ensureConnected();
      }
      final src = SshServerSource(_cmd!);
      final data = await src.getSystemInfo();
      _lastFetchTime = DateTime.now();
      return data;
    } catch (e) {
      // 连接失效时断开，下次轮询重连。
      _cmd?.disconnect();
      _cmd = null;
      rethrow;
    }
  }

  /// 静默轮询 — 失败保留旧数据, 不闪 loading
  Future<void> _poll() async {
    try {
      final data = await _fetchOnce();
      _lastFetchTime = DateTime.now();
      state = AsyncValue.data(data);
      ref.read(refreshErrorProvider.notifier).state = null;
    } catch (e, st) {
      debugPrint('Status poll failed: $e');
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// 静默手动刷新 — 不闪 loading, 保留旧数据直到成功
  Future<void> refresh() async {
    try {
      final data = await _fetchOnce();
      _lastFetchTime = DateTime.now();
      state = AsyncValue.data(data);
      ref.read(refreshErrorProvider.notifier).state = null;
    } catch (e, st) {
      debugPrint('Manual refresh failed: $e');
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final serverStatusProvider =
    AsyncNotifierProvider<ServerStatusNotifier, ServerStatus>(
      ServerStatusNotifier.new,
    );
