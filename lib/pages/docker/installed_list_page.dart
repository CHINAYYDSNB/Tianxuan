import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/installed_app_provider.dart';
import '../../models/installed_app.dart';
import 'installed_detail_page.dart';

class InstalledListPage extends ConsumerWidget {
  const InstalledListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(installedAppListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('已安装应用')),
      body: apps.when(
        data: (list) => _InstalledView(list: list),
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
                    ref.read(installedAppListProvider.notifier).refresh(),
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

class _InstalledView extends ConsumerWidget {
  final List<InstalledApp> list;

  const _InstalledView({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatableIds = ref.watch(updatableAppIdsProvider);

    if (list.isEmpty) return const Center(child: Text('未安装应用'));
    return RefreshIndicator(
      onRefresh: () => ref.read(installedAppListProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _InstalledTile(
          app: list[i],
          hasUpdate: updatableIds.contains(list[i].id),
        ),
      ),
    );
  }
}

class _InstalledTile extends StatelessWidget {
  final InstalledApp app;
  final bool hasUpdate;

  const _InstalledTile({required this.app, this.hasUpdate = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => InstalledDetailPage(
            installId: app.id,
            appName: app.name,
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.checklist,
                    color: colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(app.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (hasUpdate) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('可更新',
                                style: TextStyle(fontSize: 10, color: Colors.blue)),
                          ),
                        ],
                      ],
                    ),
                    Text(app.key,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
