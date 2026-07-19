import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/image_provider.dart';
import '../../providers/ssh_connection_provider.dart';
import '../../models/image.dart' as models;
import '../settings/ssh_config_page.dart';

class ImageListPage extends ConsumerWidget {
  const ImageListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(imageListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('镜像')),
      body: images.when(
      data: (list) => _ImageView(list: list),
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
                  ref.read(imageListProvider.notifier).refresh(),
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

class _ImageView extends ConsumerWidget {
  final List<models.DockerImage> list;

  const _ImageView({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${list.length} 个镜像',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cleaning_services_outlined, size: 20),
                tooltip: '清理废旧镜像',
                onPressed: () => _confirmPrune(context, ref),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showPullDialog(context, ref),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('拉取'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: list.isEmpty
              ? Builder(builder: (ctx) {
                  final ssh = ref.watch(sshServiceProvider);
                  if (ssh == null) {
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
                            const Text('镜像管理需要 SSH 连接服务器',
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
                  return const Center(child: Text('暂无镜像'));
                })
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(imageListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) =>
                        _ImageTile(image: list[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showPullDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拉取镜像'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'nginx:latest',
            labelText: '镜像名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                _showPullProgress(context, ref, name);
              }
            },
            child: const Text('拉取'),
          ),
        ],
      ),
    );
  }

  void _showPullProgress(BuildContext context, WidgetRef ref, String imageName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _PullProgressDialog(imageName: imageName, ref: ref);
      },
    );
  }

  void _confirmPrune(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理废旧镜像'),
        content: const Text('将删除所有未被容器使用的镜像 (docker image prune -a -f)，确定继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在清理...')),
              );
              ref.read(imageListProvider.notifier).prune(all: true).then((result) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('清理完成: $result')),
                  );
                }
                ref.read(imageListProvider.notifier).refresh();
              });
            },
            child: const Text('确定清理'),
          ),
        ],
      ),
    );
  }
}

class _PullProgressDialog extends ConsumerStatefulWidget {
  final String imageName;
  final WidgetRef ref;

  const _PullProgressDialog({required this.imageName, required this.ref});

  @override
  ConsumerState<_PullProgressDialog> createState() => _PullProgressDialogState();
}

class _PullProgressDialogState extends ConsumerState<_PullProgressDialog> {
  final _lines = <String>[];
  StreamSubscription<String>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final stream = ref.read(imageListProvider.notifier).pullStream(widget.imageName);
    _sub = stream.listen(
      (line) {
        if (mounted) {
          setState(() {
            _lines.add(line);
            if (_lines.length > 200) _lines.removeAt(0);
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _done = true);
          ref.read(imageListProvider.notifier).refresh();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _lines.add('Error: $e');
            _done = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('拉取 ${widget.imageName}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_done)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(),
                ),
              ..._lines.map((l) => Text(l,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
            ],
          ),
        ),
      ),
      actions: [
        if (_done)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
      ],
    );
  }
}

class _ImageTile extends ConsumerWidget {
  final models.DockerImage image;

  const _ImageTile({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.image, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.tagLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${image.shortId}  |  大小: ${image.formattedSize}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (image.createdAt.isNotEmpty)
                    Text(
                      '创建: ${image.createdAt}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            // Used indicator
            if (image.isUsed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('使用中',
                    style: TextStyle(fontSize: 11, color: Colors.green)),
              ),
            const SizedBox(width: 4),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.withValues(alpha: 0.7),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除镜像'),
        content: Text('确定删除 ${image.tagLabel}？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(imageListProvider.notifier)
                  .remove([image.id]);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
