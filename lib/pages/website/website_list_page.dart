import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/website.dart';
import '../../providers/website_provider.dart';
import 'website_detail_page.dart';

/// Standalone page (with Scaffold + AppBar)
class WebsiteListPage extends ConsumerWidget {
  const WebsiteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网站列表'),
      ),
      body: const WebsiteListBody(),
    );
  }
}

/// Embeddable body widget (no Scaffold/AppBar)
class WebsiteListBody extends ConsumerWidget {
  const WebsiteListBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final websites = ref.watch(websitesProvider);

    return websites.when(
      data: (list) => list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: 64, color: Color(0xFFAAB4BF)),
                  SizedBox(height: 12),
                  Text('暂无网站', style: TextStyle(fontSize: 16, color: Color(0xFF686F78))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(websitesProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _WebsiteTile(website: list[i]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$e', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.read(websitesProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
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

    return Dismissible(
      key: ValueKey('web_${website.id}'),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定删除 ${website.primaryDomain}？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        ref.read(websitesProvider.notifier).deleteWebsite(website.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${website.primaryDomain} 已删除')),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(38),
          child: Icon(Icons.language, color: color),
        ),
        title: Text(website.primaryDomain,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(website.statusLabel,
                      style: TextStyle(fontSize: 11, color: color)),
                ),
                const SizedBox(width: 8),
                Text(website.typeLabel,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF686F78))),
            ],
          ),
          if (website.sitePath != null && website.sitePath!.isNotEmpty)
            Text(website.sitePath!,
                style: const TextStyle(fontSize: 11, color: Color(0xFF686F78))),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            ref.read(websitesProvider.notifier).operateWebsite(website.id, action);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${website.primaryDomain}: ${action == "start" ? "启动" : action == "stop" ? "停止" : "重启"}中...'),
              ),
            );
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'start',
                child: ListTile(
                    leading: Icon(Icons.play_arrow, color: Colors.green),
                    title: Text('启动'))),
            const PopupMenuItem(
                value: 'stop',
                child: ListTile(
                    leading: Icon(Icons.stop, color: Colors.red),
                    title: Text('停止'))),
            const PopupMenuItem(
                value: 'restart',
                child: ListTile(
                    leading: Icon(Icons.refresh, color: Colors.blue),
                    title: Text('重启'))),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WebsiteDetailPage(websiteId: website.id),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'Running' => Colors.green,
        'Stopped' => Colors.red,
        'Error' => Colors.red,
        _ => const Color(0xFFAAB4BF),
      };
}
