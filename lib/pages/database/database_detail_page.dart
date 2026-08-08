import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../providers/database_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import 'database_detail_tabs.dart';

/// 数据库实例管理：列表 / 状态 / 设置（对齐 Mono-Dash 管理页）。
class DatabaseDetailPage extends ConsumerStatefulWidget {
  final DatabaseInstance instance;
  const DatabaseDetailPage({super.key, required this.instance});

  @override
  ConsumerState<DatabaseDetailPage> createState() => _DatabaseDetailPageState();
}

class _DatabaseDetailPageState extends ConsumerState<DatabaseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  DatabaseInstance get _inst => widget.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_inst.name} 路 ${_inst.type.label}'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '列表'),
            Tab(text: '状态'),
            Tab(text: '设置'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DatabaseListTab(inst: _inst),
          DatabaseStatusTab(inst: _inst),
          DatabaseSettingsTab(inst: _inst),
        ],
      ),
    );
  }
}

// ─── 列表 Tab ───

class _DatabaseListTab extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  const _DatabaseListTab({required this.inst});

  @override
  ConsumerState<_DatabaseListTab> createState() => _DatabaseListTabState();
}

class _DatabaseListTabState extends ConsumerState<_DatabaseListTab> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DatabaseService get _svc => ref.read(databaseServiceProvider);

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    String format = '';
    String collation = '';
    List<FormatCollationOption>? options;
    if (widget.inst.fromApi && !widget.inst.type.isRedis) {
      try {
        options = await _svc.getFormatOptions(widget.inst);
      } catch (_) {}
    }
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('创建数据库'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '数据库名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (options != null && options.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: format.isEmpty ? null : format,
                    decoration: const InputDecoration(
                      labelText: '字符集',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.format,
                            child: Text(o.format),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setDlg(() {
                        format = v ?? '';
                        collation = '';
                      });
                    },
                  ),
                  if (format.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: null,
                      decoration: const InputDecoration(
                        labelText: '排序规则',
                        border: OutlineInputBorder(),
                      ),
                      items: options
                          .firstWhere(
                            (o) => o.format == format,
                            orElse: () =>
                                const FormatCollationOption(format: ''),
                          )
                          .collations
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setDlg(() => collation = v ?? ''),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await _svc.createDatabase(
        widget.inst,
        name,
        format: format,
        collation: collation,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建成功'), backgroundColor: Colors.green),
      );
      ref.invalidate(databaseItemsProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(DatabaseItem item) async {
    final name = item.instanceName.isNotEmpty ? item.instanceName : item.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除数据库'),
        content: Text('确定删除数据库「$name」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteDatabase(widget.inst, item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除'), backgroundColor: Colors.green),
      );
      ref.invalidate(databaseItemsProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncFromRemote() async {
    try {
      if (widget.inst.type.isPostgres) {
        await _svc.loadPgFromRemote(widget.inst);
      } else {
        await _svc.loadFromRemote(widget.inst);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同步'), backgroundColor: Colors.green),
      );
      ref.invalidate(databaseItemsProvider(widget.inst.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(databaseItemsProvider(widget.inst.id));
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: '搜索数据库',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _keyword = '');
                                },
                              ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onSubmitted: (v) => setState(() => _keyword = v.trim()),
                      onChanged: (v) => setState(() => _keyword = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '从服务器同步',
                    onPressed: _syncFromRemote,
                    icon: const Icon(Icons.sync),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () =>
                        ref.invalidate(databaseItemsProvider(widget.inst.id)),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  final filtered = _keyword.isEmpty
                      ? items
                      : items
                            .where(
                              (e) =>
                                  e.name.contains(_keyword) ||
                                  e.instanceName.contains(_keyword),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        items.isEmpty ? '暂无数据库' : '没有匹配的数据库',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final db = filtered[i];
                      final dbName = db.instanceName.isNotEmpty
                          ? db.instanceName
                          : db.name;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.storage_outlined),
                          title: Text(
                            dbName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: db.format.isNotEmpty
                              ? Text(
                                  '${db.format}${db.collation.isNotEmpty ? ' 路 ${db.collation}' : ''}'
                                  '${db.username.isNotEmpty ? ' 路 ${db.username}' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () => _delete(db),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorRetry(
                  error: '$e',
                  onRetry: () =>
                      ref.invalidate(databaseItemsProvider(widget.inst.id)),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('新建数据库'),
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(fontSize: 13)),
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
