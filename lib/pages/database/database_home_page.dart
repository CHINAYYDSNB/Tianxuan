import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import 'database_add_sheet.dart';
import 'database_detail_page.dart';

/// 数据库实例列表（本地保存，手动添加 / 从 1Panel 导入）
class DatabaseHomePage extends ConsumerStatefulWidget {
  const DatabaseHomePage({super.key});

  @override
  ConsumerState<DatabaseHomePage> createState() => _DatabaseHomePageState();
}

class _DatabaseHomePageState extends ConsumerState<DatabaseHomePage> {
  bool _importing = false;

  IconData _typeIcon(DbType t) => switch (t) {
    DbType.mysql || DbType.mariadb => Icons.storage_rounded,
    DbType.postgresql => Icons.account_tree_outlined,
    DbType.mongodb => Icons.park_outlined,
    DbType.redis => Icons.memory,
  };

  Color _typeColor(DbType t) => switch (t) {
    DbType.mysql || DbType.mariadb => const Color(0xFF1976D2),
    DbType.postgresql => const Color(0xFF00838F),
    DbType.mongodb => const Color(0xFF43A047),
    DbType.redis => const Color(0xFFE53935),
  };

  Future<void> _importFromApi() async {
    setState(() => _importing = true);
    try {
      final n = await ref
          .read(databaseInstancesProvider.notifier)
          .importFromApi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n > 0 ? '已导入 $n 个数据库实例' : '没有可导入的新实例'),
          backgroundColor: n > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final instances = ref.watch(databaseInstancesProvider);
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库'),
        actions: [
          if (connected)
            IconButton(
              tooltip: '从 1Panel 导入',
              onPressed: _importing ? null : _importFromApi,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDatabaseAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加实例'),
      ),
      body: instances.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_outlined,
                      size: 56,
                      color: AppColors.iconFaint,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '还没有数据库实例',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      connected ? '点右上角从 1Panel 导入，或点右下角手动添加' : '点右下角手动添加实例',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showDatabaseAddSheet(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('手动添加'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: instances.length,
                itemBuilder: (context, i) {
                  final inst = instances[i];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DatabaseDetailPage(instance: inst),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _typeColor(
                                  inst.type,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _typeIcon(inst.type),
                                color: _typeColor(inst.type),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inst.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${inst.type.label} · ${inst.displayAddress}'
                                    '${inst.fromApi ? ' · 1Panel' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.iconFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
