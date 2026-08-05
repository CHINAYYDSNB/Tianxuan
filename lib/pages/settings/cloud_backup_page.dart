import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/backup_item.dart';
import '../../services/cloud_backup_service.dart';
import '../../providers/server_list_provider.dart';
import 'package:tianxuan/theme/app_colors.dart';

class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});

  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  bool _busy = false;
  String? _statusMsg;
  bool _isError = false;
  String? _lastBackupTime;
  Set<BackupItem> _selected = {BackupItem.servers};

  @override
  void initState() {
    super.initState();
    _loadBackupTime();
  }

  Future<void> _loadBackupTime() async {
    final t = await CloudBackupService.getBackupTime();
    if (mounted) setState(() => _lastBackupTime = t);
  }

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _statusMsg = null;
      _isError = false;
    });
    try {
      final servers = ref.read(savedServersProvider);
      await CloudBackupService.backup(
        servers: servers,
        items: _selected.toList(),
      );
      await _loadBackupTime();
      setState(() {
        _statusMsg = '备份成功 ✓  已备份 ${_selected.length} 项配置';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMsg = '上传失败: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: const Text('这将覆盖所选项目的本地配置，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _busy = true;
      _statusMsg = null;
      _isError = false;
    });
    try {
      final data = await CloudBackupService.restore();
      if (data == null) {
        setState(() {
          _statusMsg = '未找到备份文件';
          _isError = true;
        });
        return;
      }

      // 恢复服务器列表
      if (data.servers.isNotEmpty) {
        final notifier = ref.read(savedServersProvider.notifier);
        for (final s in data.servers) {
          try {
            await notifier.add(s);
          } catch (_) {}
        }
      }

      await _loadBackupTime();
      setState(() {
        _statusMsg =
            '恢复成功 ✓  已恢复 ${data.servers.length} 个服务器${data.items.isNotEmpty ? " + ${data.items.length} 项配置" : ""}';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMsg = '恢复失败: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('数据备份')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 备份项目选择
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('备份项目', style: theme.textTheme.titleMedium),
                  SizedBox(height: 4),
                  Text(
                    '勾选要备份到服务器的配置项',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in BackupItem.values)
                    CheckboxListTile(
                      title: Text(item.label),
                      subtitle: Text(
                        item.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _selected.contains(item),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(item);
                          } else {
                            _selected.remove(item);
                          }
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 状态卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined),
                      const SizedBox(width: 8),
                      Text('备份到服务器', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '存储路径: /opt/1panel/.tianxuan-backup.json',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  if (_lastBackupTime != null)
                    Text(
                      '上次备份: ${_lastBackupTime!.substring(0, 19).replaceAll('T', ' ')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _upload,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: Text(_busy ? '上传中...' : '上传备份'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _download,
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('下载恢复'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 状态消息
          if (_statusMsg != null) ...[
            const SizedBox(height: 12),
            Card(
              color: _isError
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _isError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      size: 20,
                      color: _isError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMsg!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 说明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('说明', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _Bullet('按勾选项目备份，敏感数据（API Key / AI Key / SSH）加密存储'),
                  _Bullet('存储位置：当前连接的 1Panel 服务器'),
                  _Bullet('上传覆盖旧备份，每次都是完整备份'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
