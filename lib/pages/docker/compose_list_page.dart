import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/compose_provider.dart';
import '../../models/compose.dart';

class ComposeListPage extends ConsumerWidget {
  const ComposeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composes = ref.watch(composeListProvider);

    return composes.when(
      data: (list) => _ComposeView(list: list),
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
                  ref.read(composeListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeView extends StatelessWidget {
  final List<ComposeItem> list;

  const _ComposeView({required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const Center(child: Text('暂无 Compose 项目'));
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _ComposeTile(compose: list[i]),
      ),
    );
  }
}

class _ComposeTile extends ConsumerWidget {
  final ComposeItem compose;

  const _ComposeTile({required this.compose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final runningColor = compose.isRunning ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: runningColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(compose.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: runningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(compose.statusLabel,
                      style: TextStyle(fontSize: 12, color: runningColor)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'start', child: Text('启动')),
                    const PopupMenuItem(value: 'stop', child: Text('停止')),
                    const PopupMenuItem(value: 'restart', child: Text('重启')),
                    const PopupMenuItem(value: 'down', child: Text('Down')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: '容器', value: '${compose.containerCount}'),
                const SizedBox(width: 16),
                _MiniStat(label: '运行', value: '${compose.runningCount}'),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(compose.createdBy,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
            if (compose.createdAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(compose.createdAt,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
            if (compose.containers.isNotEmpty) ...[
              const Divider(height: 12),
              ...compose.containers.take(3).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8,
                        color: c.state == 'running' ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(c.name,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在${action} ${compose.name}...')),
    );
    ref.read(composeListProvider.notifier).operate(compose.name, action, path: compose.path);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(value, style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
