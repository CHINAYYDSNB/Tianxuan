import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/compose_provider.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../models/compose.dart';
import '../settings/ssh_config_page.dart';

class ComposeListPage extends ConsumerWidget {
  const ComposeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composes = ref.watch(composeListProvider);
    final ssh = ref.watch(sshServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compose')),
      body: composes.when(
      data: (list) => _ComposeView(list: list, sshConnected: ssh != null),
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
    ),
    );
  }
}

class _ComposeView extends StatelessWidget {
  final List<ComposeItem> list;
  final bool sshConnected;

  const _ComposeView({required this.list, required this.sshConnected});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      if (!sshConnected) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 48, color: Color(0xFFAAB4BF)),
                const SizedBox(height: 16),
                const Text('SSH 未连接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Compose 管理需要 SSH 连接服务器',
                    style: TextStyle(color: Color(0xFF686F78))),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SshConfigPage())),
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('设置 SSH 连接'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: Text('暂无 Compose 项目'));
    }
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
