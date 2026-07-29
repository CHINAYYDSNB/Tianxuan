import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/container.dart' as models;
import '../../providers/container_provider.dart';
import 'container_log_page.dart';

class ContainerDetailPage extends ConsumerWidget {
  final models.Container container;

  const ContainerDetailPage({super.key, required this.container});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statsAsync = ref.watch(containerStatsProvider(container.name));

    return Scaffold(
      appBar: AppBar(title: Text(container.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoRow(label: '状态', value: container.stateLabel),
          _InfoRow(label: '镜像', value: container.imageName),
          _InfoRow(
            label: '容器 ID',
            value: container.containerID.length > 12
                ? container.containerID.substring(0, 12)
                : container.containerID,
          ),
          _InfoRow(label: '创建时间', value: container.createTime),
          if (container.runTime.isNotEmpty)
            _InfoRow(label: '运行时间', value: container.runTime),
          if (container.appName.isNotEmpty)
            _InfoRow(
              label: '所属应用',
              value: '${container.appName} (${container.appInstallName})',
            ),
          if (container.network.isNotEmpty)
            _InfoRow(label: '网络', value: container.network.join(', ')),
          if (container.ports != null && container.ports!.isNotEmpty)
            _InfoRow(label: '端口映射', value: container.ports!.join('\n')),
          if (container.isFromCompose) _InfoRow(label: '来源', value: 'Compose'),
          if (container.description.isNotEmpty)
            _InfoRow(label: '描述', value: container.description),

          const SizedBox(height: 24),
          Text('资源占用', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          statsAsync.when(
            data: (stats) => _StatGrid(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                '无法获取状态: $e',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('操作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _ActionButtons(container: container),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContainerLogPage(containerName: container.name),
              ),
            ),
            icon: const Icon(Icons.terminal, size: 18),
            label: const Text('查看日志'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final models.ContainerStats stats;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _StatItem(
                  label: 'CPU',
                  value: '${stats.cpuPercent.toStringAsFixed(1)}%',
                  icon: Icons.memory,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: '内存',
                  value: stats.formattedMemory,
                  icon: Icons.storage,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _StatItem(
                  label: '读 I/O',
                  value: '${stats.ioRead.toStringAsFixed(1)} MB',
                  icon: Icons.download,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: '写 I/O',
                  value: '${stats.ioWrite.toStringAsFixed(1)} MB',
                  icon: Icons.upload,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _StatItem(
                  label: '网络 RX',
                  value: '${stats.networkRX.toStringAsFixed(1)} MB',
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(width: 16),
                _StatItem(
                  label: '网络 TX',
                  value: '${stats.networkTX.toStringAsFixed(1)} MB',
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final models.Container container;

  const _ActionButtons({required this.container});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (container.isRunning) ...[
          _ActionBtn(
            icon: Icons.stop,
            label: '停止',
            color: Colors.red,
            onTap: () => _confirmAndRun(context, ref, '停止', 'stop'),
          ),
          _ActionBtn(
            icon: Icons.restart_alt,
            label: '重启',
            color: Colors.orange,
            onTap: () => _confirmAndRun(context, ref, '重启', 'restart'),
          ),
          _ActionBtn(
            icon: Icons.pause,
            label: '暂停',
            color: Colors.blue,
            onTap: () => _confirmAndRun(context, ref, '暂停', 'pause'),
          ),
        ],
        if (container.isStopped)
          _ActionBtn(
            icon: Icons.play_arrow,
            label: '启动',
            color: Colors.green,
            onTap: () => _confirmAndRun(context, ref, '启动', 'start'),
          ),
        if (container.isPaused)
          _ActionBtn(
            icon: Icons.play_circle,
            label: '恢复',
            color: Colors.green,
            onTap: () => _confirmAndRun(context, ref, '恢复', 'unpause'),
          ),
      ],
    );
  }

  void _confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    String label,
    String action,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${label}容器'),
        content: Text('确定${label} ${container.name}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('正在$label...')));
              ref
                  .read(containerListProvider.notifier)
                  .operate(container.name, action);
            },
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        backgroundColor: color.withValues(alpha: 0.05),
      ),
    );
  }
}
