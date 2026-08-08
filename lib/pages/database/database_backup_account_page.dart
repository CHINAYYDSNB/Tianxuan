import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/backup_provider.dart';
import '../../theme/app_colors.dart';
import 'database_backup_account_form.dart';

/// 备份账号管理页（本地 + 云存储账号 CRUD）。
class DatabaseBackupAccountPage extends ConsumerStatefulWidget {
  const DatabaseBackupAccountPage({super.key});

  @override
  ConsumerState<DatabaseBackupAccountPage> createState() =>
      _BackupAccountPageState();
}

class _BackupAccountPageState extends ConsumerState<DatabaseBackupAccountPage> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(backupServiceProvider)
          .searchAccounts(page: 1, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _accounts = result.accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final changed = await showBackupAccountForm(context, existing: existing);
    if (changed == true && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> account) async {
    final id = (account['id'] as num?)?.toInt() ?? 0;
    final name = account['name']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备份账号'),
        content: Text('确定删除备份账号「$name」吗？'),
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
      await ref.read(backupServiceProvider).deleteAccount(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (mounted) _showErr(e);
    }
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份账号')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('添加账号'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _accounts.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: _accounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _AccountCard(
                  account: _accounts[i],
                  onTap: () => _openForm(_accounts[i]),
                  onDelete: () => _delete(_accounts[i]),
                ),
              ),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 56, color: AppColors.iconFaint),
            const SizedBox(height: 16),
            const Text(
              '还没有备份账号',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '可添加本地目录或云存储（OSS/S3/SFTP 等），用于数据库备份',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = account['name']?.toString() ?? '';
    final type = account['type']?.toString() ?? '';
    final bucket = account['bucket']?.toString() ?? '';
    final backupPath = account['backupPath']?.toString() ?? '';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(_typeIcon(type), size: 22, color: _typeColor(type)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        type,
                        bucket,
                        backupPath,
                      ].where((s) => s.isNotEmpty).join(' · '),
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
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
              Icon(Icons.chevron_right, color: AppColors.iconFaint),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'OSS':
      case 'ALIYUN':
      case 'COS':
      case 'KODO':
      case 'UPYUN':
        return Icons.cloud_outlined;
      case 'S3':
      case 'MINIO':
        return Icons.cloud_queue;
      case 'SFTP':
        return Icons.dns_outlined;
      case 'WEBDAV':
        return Icons.public;
      case 'ONEDRIVE':
      case 'GOOGLEDRIVE':
        return Icons.cloud_done_outlined;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'OSS':
      case 'ALIYUN':
        return const Color(0xFFF57C00);
      case 'COS':
        return const Color(0xFF1976D2);
      case 'S3':
        return const Color(0xFFF9A825);
      case 'MINIO':
        return const Color(0xFFE53935);
      case 'SFTP':
        return const Color(0xFF43A047);
      case 'WEBDAV':
        return const Color(0xFF3949AB);
      case 'ONEDRIVE':
      case 'GOOGLEDRIVE':
        return const Color(0xFF00838F);
      default:
        return AppColors.textMuted;
    }
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

/// 打开备份账号表单，返回 true 表示有变更需刷新。
Future<bool> showBackupAccountForm(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BackupAccountFormSheet(existing: existing),
      ) ??
      false;
}
