import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';
import 'website_action_sheet.dart';
import 'package:tianxuan/theme/app_colors.dart';

/// Standalone page (with Scaffold + AppBar)
class WebsiteListPage extends ConsumerStatefulWidget {
  const WebsiteListPage({super.key});

  @override
  ConsumerState<WebsiteListPage> createState() => _WebsiteListPageState();
}

class _WebsiteListPageState extends ConsumerState<WebsiteListPage> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(websitesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索网站...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (v) =>
                    ref.read(websitesProvider.notifier).setSearch(v),
              )
            : const Text('网站列表'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                ref.read(websitesProvider.notifier).setSearch(null);
              }
            },
          ),
        ],
      ),
      body: WebsiteListBody(scrollController: _scrollCtrl),
    );
  }
}

/// Embeddable body widget (no Scaffold/AppBar)
class WebsiteListBody extends ConsumerWidget {
  final ScrollController? scrollController;

  const WebsiteListBody({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openResty = ref.watch(openRestyStatusProvider);
    final websites = ref.watch(websitesProvider);

    // OpenResty 未安装检测
    if (openResty.valueOrNull == false) {
      return _CenterState(
        icon: Icons.extension_off,
        title: '未安装 OpenResty',
        subtitle: '网站管理依赖 OpenResty 运行环境，请先在服务器安装',
      );
    }

    return websites.when(
      data: (list) {
        if (list.isEmpty) {
          return const _CenterState(
            icon: Icons.language,
            title: '暂无网站',
            subtitle: '点击右上角搜索，或稍后刷新',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(websitesProvider.notifier).refresh(),
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: list.length + 1,
            itemBuilder: (context, i) {
              if (i == list.length) {
                final hasMore = ref.read(websitesProvider.notifier).hasMore;
                // 滚动到底部时加载更多
                if (hasMore && i > 4) {
                  ref.read(websitesProvider.notifier).loadMore();
                }
                if (!hasMore) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        '没有更多了',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return _WebsiteTile(website: list[i]);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(error: e),
    );
  }
}

class _CenterState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenterState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.iconFaint),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AppColors.iconFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  final Object error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$error', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(websitesProvider.notifier).refresh(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _WebsiteTile extends ConsumerWidget {
  final Website website;

  const _WebsiteTile({required this.website});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(website.status);
    final hasSsl = website.protocol?.toLowerCase() == 'https';

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showWebsiteActionSheet(context, ref, website),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF0062F5).withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      website.typeLabel,
                      style: TextStyle(fontSize: 11, color: Color(0xFF0062F5)),
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      website.statusLabel,
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    hasSsl ? Icons.lock : Icons.lock_open,
                    size: 14,
                    color: hasSsl ? Colors.green : AppColors.iconFaint,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openSite(context, website),
                      child: Text(
                        website.primaryDomain,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: AppColors.iconFaint,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      website.sitePath ?? website.siteDir ?? '目录未设置',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.notes, size: 14, color: AppColors.iconFaint),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      website.remark.isEmpty ? '暂无备注' : website.remark,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSite(BuildContext context, Website w) async {
    final domain = w.primaryDomain.trim();
    if (domain.isEmpty) return;
    final scheme = w.protocol?.toLowerCase() == 'https' ? 'https' : 'http';
    final uri = Uri.tryParse('$scheme://$domain');
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开浏览器')));
    }
  }

  Color _statusColor(String status) => switch (status) {
    'Running' => Colors.green,
    'Stopped' => Colors.red,
    'Error' => Colors.red,
    _ => AppColors.iconFaint,
  };
}
