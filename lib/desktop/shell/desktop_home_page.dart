import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/desktop_server.dart';
import '../providers/desktop_server_provider.dart';
import '../providers/desktop_status_provider.dart';
import 'desktop_workspace_page.dart';
import 'server_edit_dialog.dart';
import '../../theme/app_colors.dart';
import '../../models/server_status.dart';

/// 桌面首页：多服务器网格卡片（MaidKit 卡片样式）+ 实时状态。
class DesktopHomePage extends ConsumerWidget {
  const DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(desktopServersProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Tianxuan Desktop',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => showServerEditDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('添加服务器'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                servers.isEmpty ? '暂无服务器，点击右上角添加' : '共 ${servers.length} 台服务器',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: servers.isEmpty
                  ? _EmptyState(onAdd: () => showServerEditDialog(context, ref))
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 340,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.55,
                          ),
                      itemCount: servers.length,
                      itemBuilder: (context, i) =>
                          DesktopServerCard(server: servers[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopServerCard extends ConsumerWidget {
  final DesktopServer server;
  const DesktopServerCard({super.key, required this.server});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(desktopStatusProvider(server.id));
    final status = statusAsync.valueOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DesktopWorkspacePage(server: server),
            ),
          );
        },
        onLongPress: () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(Icons.dns, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name.isNotEmpty ? server.name : server.host,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${server.username}@${server.host}:${server.port}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _statusDot(status),
                ],
              ),
              const Spacer(),
              _metrics(status),
              const SizedBox(height: 8),
              if (status != null && status.hostname.isNotEmpty)
                Text(
                  status.platform.isNotEmpty
                      ? '${status.hostname} · ${status.platform}'
                      : status.hostname,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(ServerStatus? status) {
    if (status == null) {
      return Icon(Icons.circle, size: 10, color: AppColors.iconFaint);
    }
    return Icon(Icons.circle, size: 10, color: Colors.green);
  }

  Widget _metrics(ServerStatus? status) {
    if (status == null) {
      return const Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.orange),
          SizedBox(width: 6),
          Text('离线 / 连接失败', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Row(
      children: [
        _metric('CPU', status.cpuUsage),
        const SizedBox(width: 12),
        _metric('内存', status.memoryUsage),
        const SizedBox(width: 12),
        _metric('磁盘', status.diskUsage),
      ],
    );
  }

  Widget _metric(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除「${server.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(desktopServersProvider.notifier).remove(server.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: AppColors.iconFaint),
          const SizedBox(height: 12),
          Text('暂无服务器', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加服务器'),
          ),
        ],
      ),
    );
  }
}
