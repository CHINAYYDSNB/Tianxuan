import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/script_store_provider.dart';
import '../../models/script_store_item.dart';
import 'script_detail_page.dart';

class ScriptStorePage extends ConsumerStatefulWidget {
  const ScriptStorePage({super.key});

  @override
  ConsumerState<ScriptStorePage> createState() => _ScriptStorePageState();
}

class _ScriptStorePageState extends ConsumerState<ScriptStorePage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(scriptIndexProvider);
    final search = ref.watch(scriptSearchProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '搜索脚本...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      onChanged: (v) => ref.read(scriptSearchProvider.notifier).state = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.invalidate(scriptIndexProvider),
                    tooltip: '刷新',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: index.when(
            data: (idx) {
              var items = idx.scripts;
              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                items = items.where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.author.toLowerCase().contains(q)
                ).toList();
              }
              if (items.isEmpty) {
                return Center(
                  child: Text(search.isEmpty ? '暂无脚本' : '没有匹配的脚本',
                      style: theme.textTheme.bodyLarge),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: items.length,
                itemBuilder: (_, i) => _ScriptCard(item: items[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('加载失败', style: theme.textTheme.titleMedium),
                    Text('$e', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(scriptIndexProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScriptCard extends StatelessWidget {
  final ScriptIndexItem item;
  const _ScriptCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          try {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ScriptDetailPage(id: item.id)),
            );
          } catch (e) {
            debugPrint('Nav error: $e');
          }
        },
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
                    Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    if (item.author.isNotEmpty)
                      Text(item.author, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              _LangBadge(language: item.language),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangBadge extends StatelessWidget {
  final String language;
  const _LangBadge({required this.language});

  @override
  Widget build(BuildContext context) {
    final isPy = language == 'python';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isPy ? Colors.blue : Colors.green).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPy ? 'Python' : 'Shell',
        style: TextStyle(fontSize: 11, color: isPy ? Colors.blue : Colors.green, fontWeight: FontWeight.w600),
      ),
    );
  }
}
