import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/website_api.dart';
import '../models/website.dart';

// ─── Website List ───

class WebsitesNotifier extends AsyncNotifier<List<Website>> {
  Timer? _timer;

  @override
  Future<List<Website>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return WebsiteApi.getList();
  }

  Future<void> _autoRefresh() async {
    try {
      final data = await WebsiteApi.getList();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => WebsiteApi.getList());
  }

  Future<void> deleteWebsite(int id) async {
    await WebsiteApi.delete(id);
    await refresh();
  }

  Future<void> operateWebsite(int id, String action) async {
    await WebsiteApi.operate(id, action);
    await refresh();
  }
}

final websitesProvider =
    AsyncNotifierProvider<WebsitesNotifier, List<Website>>(
  WebsitesNotifier.new,
);

// ─── Website Detail ───

final websiteDetailProvider =
    FutureProvider.family<Website, int>((ref, id) async {
  return WebsiteApi.getDetail(id);
});

// ─── Nginx Config ───

final websiteConfigProvider =
    FutureProvider.family<String?, int>((ref, id) async {
  return WebsiteApi.getConfig(id);
});

// ─── HTTPS ───

final websiteHttpsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return WebsiteApi.getHttps(id);
});

// ─── Log ───

final websiteLogProvider =
    FutureProvider.family<Map<String, dynamic>, ({int id, String logType})>(
        (ref, params) async {
  return WebsiteApi.getLog(params.id, params.logType);
});

// ─── Directory ───

final websiteDirProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  return WebsiteApi.getDir(id);
});

// ─── Create Website ───

final websiteCreateProvider = FutureProvider.family<int, WebsiteCreateRequest>(
  (ref, req) async {
    return WebsiteApi.create(req);
  },
);
