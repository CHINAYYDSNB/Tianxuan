import 'package:flutter/material.dart';
import '../../api/website_api.dart';
import 'website_sheet_widgets.dart';

/// 关联资源弹层
void showResourceSheet(BuildContext context, int websiteId) {
  showWebsiteSheet(
    context: context,
    title: '关联资源',
    initialSize: 0.7,
    child: ResourceSheet(websiteId: websiteId),
  );
}

class ResourceSheet extends StatefulWidget {
  final int websiteId;
  const ResourceSheet({super.key, required this.websiteId});

  @override
  State<ResourceSheet> createState() => _ResourceSheetState();
}

class _ResourceSheetState extends State<ResourceSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = WebsiteApi.getResources(widget.websiteId);
  }

  void _reload() {
    setState(() => _future = WebsiteApi.getResources(widget.websiteId));
  }

  Future<void> _changeDatabase() async {
    try {
      final dbs = await WebsiteApi.getDatabases();
      if (!mounted || dbs.isEmpty) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('更换数据库'),
          children: [
            for (final db in dbs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, db),
                child: Text(db['name']?.toString() ?? ''),
              ),
          ],
        ),
      );
      if (selected != null && mounted) {
        await WebsiteApi.changeDatabase({
          'websiteID': widget.websiteId,
          'databaseID': (selected['id'] as num?)?.toInt() ?? 0,
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('数据库已更换')));
          _reload();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '关联的数据库 / FTP',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.sync_alt, size: 18),
                onPressed: _changeDatabase,
                label: const Text('更换数据库'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SheetLoading();
              }
              if (snap.hasError) {
                return SheetError(error: snap.error!, onRetry: _reload);
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('暂无关联资源'));
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = list[i];
                  final type = r['type']?.toString() ?? '';
                  return ListTile(
                    leading: Icon(
                      type == 'database' ? Icons.storage : Icons.dns,
                      color: type == 'database' ? Colors.teal : Colors.orange,
                    ),
                    title: Text(r['name']?.toString() ?? ''),
                    subtitle: Text(r['format']?.toString() ?? type),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
