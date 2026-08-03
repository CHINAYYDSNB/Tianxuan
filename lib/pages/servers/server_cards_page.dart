import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/server_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/server_add_sheet.dart';
import '../dashboard/dashboard_page.dart';

/// 首页：多服务器卡片概览
class ServerCardsPage extends ConsumerWidget {
  const ServerCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(savedServersProvider);
    final currUrl = ref.watch(settingsProvider.select((s) => s.serverUrl));

    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加服务器',
            onPressed: () => showServerAddSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () {
              ref.read(serverStatusProvider.notifier).refresh();
              for (final s in servers) {
                ref.invalidate(serverCardStatusProvider(s.id));
              }
            },
          ),
        ],
      ),
      body: servers.isEmpty
          ? _EmptyState(onAdd: () => showServerAddSheet(context, ref))
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(serverStatusProvider.notifier).refresh();
                for (final s in servers) {
                  ref.invalidate(serverCardStatusProvider(s.id));
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: servers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = servers[i];
                  final isCurrent = s.url == currUrl;
                  return _ServerCard(
                    server: s,
                    isCurrent: isCurrent,
                    onTap: () => _openServer(context, ref, s, isCurrent),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _openServer(
    BuildContext context,
    WidgetRef ref,
    SavedServer server,
    bool isCurrent,
  ) async {
    if (!isCurrent) {
      final err = await ref
          .read(savedServersProvider.notifier)
          .switchTo(server);
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $err'), backgroundColor: Colors.red),
        );
        return;
      }
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('暂无服务器', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '点击下方按钮添加 1Panel 服务器',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('添加服务器'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerCard extends ConsumerWidget {
  final SavedServer server;
  final bool isCurrent;
  final VoidCallback onTap;

  const _ServerCard({
    required this.server,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(serverCardStatusProvider(server.id));
    final status = statusAsync.valueOrNull;
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dns,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          server.displayUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF686F78),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '当前',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Color(0xFFAAB4BF)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // 迷你监控
              statusAsync.when(
                data: (s) => s == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Color(0xFFAAB4BF),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '状态获取失败',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFAAB4BF),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          _metric(context, 'CPU', s.cpuUsage),
                          _metricSep(),
                          _metric(context, '内存', s.memoryUsage),
                          _metricSep(),
                          _metric(context, '磁盘', s.diskUsage),
                        ],
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('获取状态...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                error: (e, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '连接失败',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (status != null && status.hostname.isNotEmpty)
                Text(
                  '${status.hostname} · ${status.platform}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFAAB4BF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, double value) {
    final color = value > 85
        ? Colors.red
        : value > 60
        ? Colors.orange
        : Colors.green;
    return Expanded(
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF686F78)),
          ),
        ],
      ),
    );
  }

  Widget _metricSep() =>
      const SizedBox(height: 28, child: VerticalDivider(width: 16));
}
