import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_colors.dart';
import 'database_detail_page.dart';
import '../settings/ssh_config_page.dart';

/// 数据库管理（移植自 Lanxi）：SSH 自动检测实例，按类型分组。
class DatabaseHomePage extends ConsumerStatefulWidget {
  const DatabaseHomePage({super.key});

  @override
  ConsumerState<DatabaseHomePage> createState() => _DatabaseHomePageState();
}

class _DatabaseHomePageState extends ConsumerState<DatabaseHomePage> {
  Map<DbType, List<DbInstance>> _grouped = {};
  bool _loading = true;
  String? _error;

  static const _order = [
    DbType.mysql,
    DbType.postgresql,
    DbType.mongodb,
    DbType.redis,
  ];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final svc = ref.read(databaseServiceProvider);
    if (svc == null) {
      setState(() {
        _loading = false;
        _error = 'SSH 未连接';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await svc.detectAll();
      final grouped = <DbType, List<DbInstance>>{};
      for (final inst in all) {
        grouped.putIfAbsent(inst.type, () => []).add(inst);
      }
      if (mounted) setState(() => _grouped = grouped);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = ref.watch(databaseServiceProvider);

    if (svc == null) {
      return Scaffold(
        appBar: AppBar(title: Text('数据库')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terminal_outlined, size: 48, color: Colors.orange),
                SizedBox(height: 12),
                Text(
                  'SSH 未连接',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '数据库管理通过 SSH 检测与操作，请先配置 SSH 连接',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SshConfigPage()),
                    );
                    _scan();
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('去配置 SSH'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('数据库'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _scan)],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text(_error!, style: TextStyle(fontSize: 13)),
                  SizedBox(height: 16),
                  FilledButton(onPressed: _scan, child: Text('重试')),
                ],
              ),
            )
          : _grouped.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storage_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '未检测到数据库实例',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '支持 MySQL / PostgreSQL / MongoDB / Redis\n宿主机与 Docker 容器',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新检测'),
                    onPressed: _scan,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _scan,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: _order
                    .where((t) => _grouped.containsKey(t))
                    .expand<Widget>((type) {
                      final list = _grouped[type]!;
                      return [
                        _typeHeader(type, list.length),
                        ...list.map((inst) => _instanceCard(inst, type)),
                        const SizedBox(height: 8),
                      ];
                    })
                    .toList(),
              ),
            ),
    );
  }

  (IconData, Color) _typeMeta(DbType type) => switch (type) {
    DbType.mysql => (Icons.storage, Colors.blue),
    DbType.postgresql => (Icons.storage, Colors.indigo),
    DbType.mongodb => (Icons.storage, Colors.green),
    DbType.redis => (Icons.memory, Colors.red),
  };

  Widget _typeHeader(DbType type, int count) {
    final (icon, color) = _typeMeta(type);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instanceCard(DbInstance inst, DbType type) {
    final (icon, color) = _typeMeta(type);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(
          inst.label,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          inst.subtitle,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inst.authFailed)
              Icon(Icons.lock, color: Colors.red, size: 18)
            else if (inst.authUser != null)
              Icon(Icons.lock_open, color: Colors.green, size: 18),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.iconFaint),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DatabaseDetailPage(
              instance: inst,
              onAuthChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }
}
