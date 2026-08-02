import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/website_api.dart';
import '../models/website.dart';

// ─── Website List ───

class WebsitesNotifier extends AsyncNotifier<List<Website>> {
  Timer? _timer;
  int _page = 1;
  static const _pageSize = 20;
  bool _hasMore = true;
  String _search = '';

  @override
  Future<List<Website>> build() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _autoRefresh());
    ref.onDispose(() => _timer?.cancel());
    return _loadPage(1, reset: true);
  }

  Future<void> _autoRefresh() async {
    try {
      final result = await WebsiteApi.search(page: 1, pageSize: _pageSize);
      state = AsyncValue.data(result['items'] as List<Website>);
    } catch (e, st) {
      if (state is! AsyncData) state = AsyncValue.error(e, st);
    }
  }

  Future<List<Website>> _loadPage(int page, {bool reset = false}) async {
    final result = await WebsiteApi.search(
      page: page,
      pageSize: _pageSize,
      search: _search.isEmpty ? null : _search,
    );
    final items = result['items'] as List<Website>;
    final total = result['total'] as int? ?? items.length;
    _hasMore = _page * _pageSize < total;
    if (reset) {
      return items;
    }
    final current = state.value ?? <Website>[];
    return [...current, ...items];
  }

  Future<void> refresh() async {
    _page = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1, reset: true));
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    _page++;
    final current = state.value ?? <Website>[];
    state = await AsyncValue.guard(() => _loadPage(_page));
    // 防止 guard 失败覆盖已有数据
    if (state.hasError) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> setSearch(String? s) async {
    _search = s?.trim() ?? '';
    _page = 1;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(1, reset: true));
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

final websitesProvider = AsyncNotifierProvider<WebsitesNotifier, List<Website>>(
  WebsitesNotifier.new,
);

// ─── OpenResty 状态 ───

final openRestyStatusProvider = FutureProvider<bool>((ref) {
  return WebsiteApi.isOpenRestyInstalled();
});

// ─── Website Detail ───

final websiteDetailProvider = FutureProvider.family<Website, int>((
  ref,
  id,
) async {
  return WebsiteApi.getDetail(id);
});

// ─── Nginx Config ───

final websiteConfigProvider = FutureProvider.family<String?, int>((
  ref,
  id,
) async {
  return WebsiteApi.getConfig(id);
});

// ─── HTTPS ───

final websiteHttpsProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) async {
  return WebsiteApi.getHttps(id);
});

// ─── Log ───

final websiteLogProvider =
    FutureProvider.family<Map<String, dynamic>, ({int id, String logType})>((
      ref,
      params,
    ) async {
      return WebsiteApi.getLog(params.id, params.logType);
    });

// ─── Directory ───

final websiteDirProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) async {
  return WebsiteApi.getDir(id);
});

// ─── Create Website ───

final websiteCreateProvider = FutureProvider.family<int, WebsiteCreateRequest>((
  ref,
  req,
) async {
  return WebsiteApi.create(req);
});
