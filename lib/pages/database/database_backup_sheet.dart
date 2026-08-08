import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/backup_record.dart';
import '../../models/database.dart';
import '../../providers/backup_provider.dart';
import '../../theme/app_colors.dart';
import 'task_log_sheet.dart';

/// 数据库备份记录列表 Sheet（创建/恢复/删除/下载）。
Future<void> showDatabaseBackupSheet(
  BuildContext context, {
  required DatabaseInstance inst,
  required String dbName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DatabaseBackupSheet(inst: inst, dbName: dbName),
  );
}

class DatabaseBackupSheet extends ConsumerStatefulWidget {
  final DatabaseInstance inst;
  final String dbName;

  const DatabaseBackupSheet({
    super.key,
    required this.inst,
    required this.dbName,
  });

  @override
  ConsumerState<DatabaseBackupSheet> createState() =>
      _DatabaseBackupSheetState();
}

class _DatabaseBackupSheetState extends ConsumerState<DatabaseBackupSheet> {
  ({String instanceId, String detailName}) get _key =>
      (instanceId: widget.inst.id, detailName: widget.dbName);

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(backupRecordsProvider(_key));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '备份记录 · ${widget.dbName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '新建备份',
                  icon: const Icon(Icons.add),
                  onPressed: _createBackup,
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: asyncState.when(
              data: (state) {
                if (state.records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: AppColors.iconFaint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无备份记录',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _createBackup,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('立即备份'),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      state.records.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == state.records.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final record = state.records[i];
                    return _BackupRecordCard(
                      inst: widget.inst,
                      dbName: widget.dbName,
                      record: record,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrRetry(
                error: '$e',
                onRetry: () =>
                    ref.read(backupRecordsProvider(_key).notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    final secretCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isMysql =
        widget.inst.type == DbType.mysql || widget.inst.type == DbType.mariadb;
    final selectedArgs = <String>{};
    const mysqlArgs = ['--single-transaction', '--quick', '--skip-lock-tables'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('新建备份'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: secretCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '压缩密码（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (isMysql) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'mysqldump 参数',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  for (final arg in mysqlArgs)
                    CheckboxListTile(
                      value: selectedArgs.contains(arg),
                      onChanged: (v) => setDlg(() {
                        if (v == true) {
                          selectedArgs.add(arg);
                        } else {
                          selectedArgs.remove(arg);
                        }
                      }),
                      title: Text(
                        arg,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('开始备份'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final taskID = await ref
          .read(backupRecordsProvider(_key).notifier)
          .backup(
            secret: secretCtrl.text.trim(),
            description: descCtrl.text.trim(),
            args: selectedArgs.toList(),
          );
      if (!mounted) return;
      await showTaskLogSheet(context, taskID: taskID);
    } catch (e) {
      if (mounted) _snack('备份失败: $e');
    }
  }

  void _snack(String msg, {bool green = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: green ? Colors.green : Colors.red,
      ),
    );
  }
}

class _BackupRecordCard extends ConsumerWidget {
  final DatabaseInstance inst;
  final String dbName;
  final BackupRecord record;

  const _BackupRecordCard({
    required this.inst,
    required this.dbName,
    required this.record,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = record.isSuccess;
    final statusColor = ok ? Colors.green : Colors.orange;
    final key = (instanceId: inst.id, detailName: dbName);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_fmtSize(record.size)} · ${_fmtTime(record.createdAt)}'
              '${record.description.isNotEmpty ? ' · ${record.description}' : ''}',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: _action(
                    context,
                    Icons.download_outlined,
                    '下载',
                    Colors.green,
                    () => _download(context, ref, key),
                  ),
                ),
                Expanded(
                  child: _action(
                    context,
                    Icons.restore,
                    '恢复',
                    Colors.blue,
                    () => _recover(context, ref, key),
                  ),
                ),
                Expanded(
                  child: _action(
                    context,
                    Icons.delete_outline,
                    '删除',
                    Colors.red,
                    () => _delete(context, ref, key),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    ({String instanceId, String detailName}) key,
  ) async {
    try {
      await ref.read(backupRecordsProvider(key).notifier).download(record);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _recover(
    BuildContext context,
    WidgetRef ref,
    ({String instanceId, String detailName}) key,
  ) async {
    final secretCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: TextField(
          controller: secretCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '备份密码（可选）',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('开始恢复'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final taskID = await ref
          .read(backupRecordsProvider(key).notifier)
          .recover(record, secret: secretCtrl.text.trim());
      if (!context.mounted) return;
      await showTaskLogSheet(context, taskID: taskID);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ({String instanceId, String detailName}) key,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定删除备份「${record.fileName}」吗？'),
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
      await ref.read(backupRecordsProvider(key).notifier).delete(record);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmtSize(int size) {
    if (size <= 0) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '--';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrRetry({required this.error, required this.onRetry});

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
