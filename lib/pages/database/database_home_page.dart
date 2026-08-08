import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import 'database_add_sheet.dart';
import 'database_backup_account_page.dart';
import 'database_detail_page.dart';
import 'database_remote_create_sheet.dart';
import 'redis_management_page.dart';

/// 数据库实例列表：按类型分组（对齐 Mono-Dash），支持手动添加 / 1Panel 导入 / 远程连接。
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

  Future<void> _importRemote() async {
    setState(() => _importing = true);
    try {
      final n = await ref
          .read(databaseInstancesProvider.notifier)
          .importRemote();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n > 0 ? '已同步 $n 个远程实例' : '没有新的远程实例'),
          backgroundColor: n > 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _openInstance(DatabaseInstance inst) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => inst.type.isRedis
            ? RedisManagementPage(instance: inst)
            : DatabaseDetailPage(instance: inst),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instances = ref.watch(databaseInstancesProvider);
    final connected = ref.watch(settingsProvider.select((s) => s.isConnected));
    final grouped = _groupByType(instances);

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
          IconButton(
            tooltip: '同步远程实例',
            onPressed: _importing ? null : _importRemote,
            icon: const Icon(Icons.add_link),
          ),
          IconButton(
            tooltip: '备份账号',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DatabaseBackupAccountPage(),
              ),
            ),
            icon: const Icon(Icons.cloud_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDatabaseAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('添加实例'),
      ),
      body: instances.isEmpty
          ? _buildEmpty(context, connected)
          : RefreshIndicator(
              onRefresh: () async {
                if (connected) await _importFromApi();
                await _importRemote();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  for (final entry in grouped.entries) ...[
                    _typeHeader(entry.key, entry.value),
                    ...entry.value.map(
                      (inst) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InstanceCard(
                          instance: inst,
                          icon: _typeIcon(inst.type),
                          color: _typeColor(inst.type),
                          onTap: () => _openInstance(inst),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _typeHeader(DbType type, List<DatabaseInstance> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(_typeIcon(type), size: 16, color: _typeColor(type)),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${list.length}',
            style: TextStyle(fontSize: 12, color: AppColors.iconFaint),
          ),
        ],
      ),
    );
  }

  static Map<DbType, List<DatabaseInstance>> _groupByType(
    List<DatabaseInstance> instances,
  ) {
    final map = <DbType, List<DatabaseInstance>>{};
    for (final inst in instances) {
      map.putIfAbsent(inst.type, () => []).add(inst);
    }
    return map;
  }

  Widget _buildEmpty(BuildContext context, bool connected) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storage_outlined, size: 56, color: AppColors.iconFaint),
            const SizedBox(height: 16),
            const Text(
              '还没有数据库实例',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              connected
                  ? '可从右上角导入 1Panel 实例 / 远程实例，或点击右下角手动添加'
                  : '点击右下角手动添加实例（支持 SSH 直连）',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => showDatabaseAddSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('手动添加'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => showDatabaseRemoteCreateSheet(
                context,
                dbType: 'mysql',
                onSuccess: _importRemote,
              ),
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('添加远程连接'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstanceCard extends StatelessWidget {
  final DatabaseInstance instance;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InstanceCard({
    required this.instance,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            instance.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (instance.version.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              instance.version,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${instance.type.label} 路 ${instance.displayAddress}'
                      '${instance.isRemote
                          ? ' 路 远程'
                          : instance.fromApi
                          ? ' 路 1Panel'
                          : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.iconFaint),
            ],
          ),
        ),
      ),
    );
  }
}
