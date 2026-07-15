import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/container_provider.dart';
import '../../models/container.dart' as models;
import 'container_detail_page.dart';
import 'container_log_page.dart';

class ContainerListPage extends ConsumerWidget {
  const ContainerListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containers = ref.watch(containerListProvider);

    return containers.when(
      data: (list) => _ContainerListView(list: list),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$e', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(containerListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContainerListView extends StatelessWidget {
  final List<models.Container> list;

  const _ContainerListView({required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const Center(child: Text('暂无容器'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh via parent widget's ref — handled by the provider above
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _ContainerTile(container: list[i]),
      ),
    );
  }
}

class _ContainerTile extends ConsumerWidget {
  final models.Container container;

  const _ContainerTile({required this.container});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (container.state) {
      'running' => Colors.green,
      'exited' || 'stopped' => Colors.red,
      'paused' => Colors.orange,
      _ => const Color(0xFFAAB4BF),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContainerDetailPage(container: container),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      container.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (container.imageName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        container.imageName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (container.runTime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        container.runTime,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // State label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  container.stateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Overflow menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (action) => _handleAction(context, ref, action),
                itemBuilder: (_) => [
                  if (container.isRunning) ...[
                    const PopupMenuItem(value: 'stop', child: Text('停止')),
                    const PopupMenuItem(value: 'restart', child: Text('重启')),
                    const PopupMenuItem(value: 'pause', child: Text('暂停')),
                  ],
                  if (container.isStopped)
                    const PopupMenuItem(value: 'start', child: Text('启动')),
                  if (container.isPaused)
                    const PopupMenuItem(value: 'unpause', child: Text('恢复')),
                  const PopupMenuItem(value: 'log', child: Text('日志')),
                  const PopupMenuItem(value: 'detail', child: Text('详情')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'detail') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContainerDetailPage(container: container),
        ),
      );
      return;
    }
    if (action == 'log') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ContainerLogPage(containerName: container.name),
        ),
      );
      return;
    }

    final label = switch (action) {
      'start' => '启动',
      'stop' => '停止',
      'restart' => '重启',
      'pause' => '暂停',
      'unpause' => '恢复',
      _ => action,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在${label} ${container.name}...')),
    );

    ref.read(containerListProvider.notifier).operate(container.name, action);
  }
}
