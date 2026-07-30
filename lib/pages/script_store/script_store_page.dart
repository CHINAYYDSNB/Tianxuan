import 'package:flutter/material.dart';
import 'package:tianxuan/models/script_store.dart';
import 'package:tianxuan/services/script_store_service.dart';
import 'script_detail_page.dart';

class ScriptStorePage extends StatefulWidget {
  const ScriptStorePage({super.key});

  @override
  State<ScriptStorePage> createState() => _ScriptStorePageState();
}

class _ScriptStorePageState extends State<ScriptStorePage> {
  late Future<List<ScriptSummary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ScriptStoreService().getIndex();
  }

  Future<void> _refresh() async {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('脚本商店'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<ScriptSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: _refresh,
            );
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Text('暂无脚本', style: theme.textTheme.bodyLarge),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length,
            itemBuilder: (_, i) => _ScriptCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _ScriptCard extends StatelessWidget {
  final ScriptSummary item;
  const _ScriptCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ScriptDetailPage(id: item.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.code, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(item.category, style: theme.textTheme.labelSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('脚本商店不可用', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
