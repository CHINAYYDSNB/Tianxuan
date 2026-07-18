import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dashboard_api.dart';
import '../models/server_status.dart';

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
      final elapsed = DateTime.now().difference(notifier.lastFetchTime).inSeconds;
      final total = data.uptimeSeconds + elapsed;
      if (total <= 0) return data.uptime;
      final days = total ~/ 86400;
      final hours = (total % 86400) ~/ 3600;
      final minutes = (total % 3600) ~/ 60;
      final parts = <String>[];
      if (days > 0) parts.add('${days}天');
      if (hours > 0) parts.add('${hours}小时');
      if (minutes > 0) parts.add('${minutes}分');
      parts.add('${total % 60}秒');
      return parts.join(' ');
    },
    loading: () => '加载中...',
    error: (_, __) => '获取失败',
  );
});

class ServerStatusNotifier extends AsyncNotifier<ServerStatus> {
  Timer? _timer;
  DateTime _lastFetchTime = DateTime(2000);

  @override
  Future<ServerStatus> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _autoRefresh());    ref.onDispose(() => _timer?.cancel());
    _lastFetchTime = DateTime.now();
    return DashboardApi.getStatus();
  }

  DateTime get lastFetchTime => _lastFetchTime;

  /// 静默刷新 — 失败保留旧数据, 不闪 loading
  Future<void> _autoRefresh() async {
    try {
      final data = await DashboardApi.getStatus();
      _lastFetchTime = DateTime.now();
      state = AsyncValue.data(data);
      ref.read(refreshErrorProvider.notifier).state = null;
    } catch (e, st) {
      debugPrint('AutoRefresh failed: $e');
      if (!_isTimeout(e)) {
        ref.read(refreshErrorProvider.notifier).state = e.toString();
      }
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// 静默手动刷新 — 不闪 loading, 保留旧数据直到成功
  Future<void> refresh() async {
    try {
      final data = await DashboardApi.getStatus();
      _lastFetchTime = DateTime.now();
      state = AsyncValue.data(data);
      ref.read(refreshErrorProvider.notifier).state = null;
    } catch (e, st) {
      debugPrint('ManualRefresh failed: $e');
      if (!_isTimeout(e)) {
        ref.read(refreshErrorProvider.notifier).state = e.toString();
      }
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  bool _isTimeout(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          (e.message?.isEmpty ?? false);
    }
    return false;
  }
}

final serverStatusProvider =
    AsyncNotifierProvider<ServerStatusNotifier, ServerStatus>(
  ServerStatusNotifier.new,
);
